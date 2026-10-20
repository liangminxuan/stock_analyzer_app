"""限流与 CORS 的回归测试（审计 P1-3）。"""

import app as backend_app
import cache_store
import routes_market


class TestRateLimit:
    def test_requests_are_limited_per_ip(self, client, monkeypatch):
        monkeypatch.setenv('RATE_LIMIT_MAX_REQUESTS', '2')
        monkeypatch.setenv('RATE_LIMIT_WINDOW_SECONDS', '60')
        monkeypatch.setattr(routes_market, 'get_stock_data', lambda: None)
        cache_store._rate_limit_hits.clear()

        first = client.get('/api/stock/screen?pe_max=20')
        second = client.get('/api/stock/screen?pe_max=20')
        third = client.get('/api/stock/screen?pe_max=20')

        assert first.status_code == 200
        assert second.status_code == 200
        assert third.status_code == 429
        assert third.get_json()['success'] is False

    def test_limiter_can_be_disabled(self, client, monkeypatch):
        monkeypatch.setenv('RATE_LIMIT_MAX_REQUESTS', '0')
        monkeypatch.setattr(routes_market, 'get_stock_data', lambda: None)
        cache_store._rate_limit_hits.clear()

        for _ in range(5):
            assert client.get('/api/stock/screen').status_code == 200

    def test_hit_table_is_bounded(self, monkeypatch):
        monkeypatch.setenv('RATE_LIMIT_MAX_REQUESTS', '10')
        cache_store._rate_limit_hits.clear()
        for i in range(cache_store._RATE_LIMIT_MAX_KEYS + 5):
            cache_store._rate_limit_hits[f'10.0.0.{i}'] = [1.0]
        # 触发一次真实请求，让淘汰逻辑执行
        with backend_app.app.test_client() as test_client:
            test_client.get('/api/stock/ai_analysis?code=600519')

        assert len(cache_store._rate_limit_hits) <= cache_store._RATE_LIMIT_MAX_KEYS


class TestCors:
    def test_cross_origin_not_allowed_by_default(self, client):
        response = client.get('/health', headers={'Origin': 'https://evil.example'})

        assert 'Access-Control-Allow-Origin' not in response.headers
