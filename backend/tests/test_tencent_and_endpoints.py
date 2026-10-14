"""腾讯行情解析与接口行为的回归测试。

对应审计报告：
- P1-3 无鉴权 / debug 端点线上公开
- P0-1 接口失败时不得返回编造数据
- P2-1 兜底数据不得携带假基本面
"""

import pandas as pd
import pytest

import app as backend_app


def _tencent_line(code, name, price, pe, pb, mcap, fields=60):
    values = [''] * fields
    values[0] = '1'
    values[1] = name
    values[2] = code
    values[3] = str(price)
    values[4] = '9.5'
    values[32] = '1.5'
    values[38] = '0.8'
    values[39] = str(pe)
    values[44] = str(mcap)
    values[46] = str(pb)
    prefix = 'sh' if code.startswith('6') else 'sz'
    return f'v_{prefix}{code}="{"~".join(values)}";'


class _FakeResponse:
    def __init__(self, text):
        self.content = text.encode('gbk')


class TestTencentQuoteParsing:
    def test_parses_fields(self, monkeypatch):
        payload = _tencent_line('600519', '贵州茅台', 1274.89, 22.5, 7.8, 16000.0)
        monkeypatch.setattr(
            'requests.get',
            lambda url, timeout=None, headers=None: _FakeResponse(payload),
        )

        result = backend_app._tencent_quote(['600519'])

        assert '600519' in result
        quote = result['600519']
        assert quote['name'] == '贵州茅台'      # GBK 正确解码
        assert quote['price'] == pytest.approx(1274.89)
        assert quote['pe_ttm'] == pytest.approx(22.5)
        assert quote['pb'] == pytest.approx(7.8)
        assert quote['mcap_yi'] == pytest.approx(16000.0)

    def test_malformed_numeric_field_does_not_drop_whole_batch(self, monkeypatch):
        """单个字段为 '-' 时，整批（最多 50 只）不应全部丢失。"""
        payload = _tencent_line('600519', '贵州茅台', 1274.89, '-', '-', '-')
        monkeypatch.setattr(
            'requests.get',
            lambda url, timeout=None, headers=None: _FakeResponse(payload),
        )

        result = backend_app._tencent_quote(['600519'])

        assert '600519' in result
        assert result['600519']['pe_ttm'] == 0.0
        assert result['600519']['price'] == pytest.approx(1274.89)

    def test_empty_codes_returns_empty(self):
        assert backend_app._tencent_quote([]) == {}

    def test_request_failure_returns_empty_without_raising(self, monkeypatch):
        def boom(*_args, **_kwargs):
            raise OSError('network down')

        monkeypatch.setattr('requests.get', boom)

        assert backend_app._tencent_quote(['600519']) == {}


class TestDebugEndpointGuard:
    def test_debug_endpoint_disabled_by_default(self, client, monkeypatch):
        monkeypatch.delenv('ENABLE_DEBUG_ENDPOINTS', raising=False)

        response = client.get('/api/debug/test_akshare')

        assert response.status_code == 404
        assert response.get_json()['success'] is False

    def test_debug_endpoint_available_when_explicitly_enabled(self, client, monkeypatch):
        monkeypatch.setenv('ENABLE_DEBUG_ENDPOINTS', '1')
        monkeypatch.setattr(
            backend_app.ak, 'stock_zh_a_spot_em',
            lambda: pd.DataFrame([{'代码': '600519', '名称': '贵州茅台'}]),
        )
        monkeypatch.setattr(
            backend_app.ak, 'stock_zh_a_spot',
            lambda: pd.DataFrame([{'代码': '600519'}]),
        )

        response = client.get('/api/debug/test_akshare')

        assert response.status_code == 200
        assert response.get_json()['results']['stock_zh_a_spot_em']['success'] is True


class TestHealthAndErrors:
    def test_health_ok(self, client):
        response = client.get('/health')

        assert response.status_code == 200
        assert response.get_json()['status'] == 'ok'

    def test_screen_returns_error_when_data_unavailable(self, client, monkeypatch):
        monkeypatch.setattr(backend_app, 'get_stock_data', lambda: None)

        response = client.get('/api/stock/screen?pe_max=20')
        body = response.get_json()

        assert body['success'] is False
        assert body['data'] == []

    def test_recommend_returns_error_when_data_unavailable(self, client, monkeypatch):
        monkeypatch.setattr(backend_app, 'get_stock_data', lambda: None)

        response = client.get('/api/stock/recommend?count=5')
        body = response.get_json()

        assert body['success'] is False

    def test_ai_analysis_requires_code(self, client):
        response = client.get('/api/stock/ai_analysis')
        body = response.get_json()

        assert body['success'] is False
        assert '股票代码' in body['error']


class TestFallbackData:
    def test_bluechip_pool_has_no_fabricated_fundamentals(self):
        """兜底池只应提供名称，不应再内置 PE/PB/市值（审计 P2-1）。"""
        for code, value in backend_app.BLUECHIP_POOL.items():
            assert isinstance(value, str), f'{code} 的兜底值应只是名称'
