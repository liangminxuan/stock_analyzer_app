"""后台预拉取 / 快照 / 非阻塞读取的回归测试（审计 P2-2）。

关键断言：
1. 请求路径不再阻塞（无数据时立刻返回 None / 提示“准备中”）；
2. 快照能落盘并冷启动加载；
3. 刷新后 loading 标志复位（旧实现成功后永不复位）。
"""

import gzip
import json
import time
from datetime import datetime, timedelta, timezone


import market_data


def beijing_ts(weekday, hour, minute=0):
    """构造“北京时间某天某时”对应的 UTC 时间戳（2026-10-05 是周一）"""
    monday = datetime(2026, 10, 5, tzinfo=timezone.utc)  # 北京 08:00 周一
    moment = monday + timedelta(days=weekday, hours=hour - 8, minutes=minute)
    return moment.timestamp()


class TestTradingTime:
    def test_weekday_morning_and_afternoon(self):
        assert market_data.is_trading_time(beijing_ts(0, 10, 0)) is True
        assert market_data.is_trading_time(beijing_ts(2, 14, 30)) is True

    def test_lunch_break_and_before_open(self):
        assert market_data.is_trading_time(beijing_ts(1, 12, 0)) is False
        assert market_data.is_trading_time(beijing_ts(1, 9, 0)) is False
        assert market_data.is_trading_time(beijing_ts(1, 15, 30)) is False

    def test_weekend_is_not_trading(self):
        assert market_data.is_trading_time(beijing_ts(5, 10, 0)) is False
        assert market_data.is_trading_time(beijing_ts(6, 14, 0)) is False


class TestNonBlockingRead:
    def test_returns_none_immediately_when_no_data(self):
        start = time.time()
        assert market_data.get_stock_data() is None
        assert time.time() - start < 0.1   # 旧实现会阻塞 120s

    def test_returns_cached_df(self, sample_df):
        market_data._stock_data_cache['df'] = sample_df
        market_data._stock_data_cache['last_update'] = time.time()

        result = market_data.get_stock_data()

        assert result is not None
        assert len(result) == 2

    def test_wait_seconds_still_supported_for_scripts(self, sample_df):
        market_data._stock_data_cache['df'] = sample_df
        assert market_data.get_stock_data(wait_seconds=1) is not None

    def test_age_and_loading_helpers(self, sample_df):
        assert market_data.stock_data_age() is None

        market_data._stock_data_cache['df'] = sample_df
        market_data._stock_data_cache['last_update'] = time.time() - 30
        age = market_data.stock_data_age()

        assert age is not None and 29 <= age <= 31
        assert market_data.stock_data_is_loading() is False
        assert market_data.stock_data_error() is None


class TestSnapshot:
    def test_save_and_load_roundtrip(self, tmp_path, monkeypatch, sample_df):
        snapshot_path = tmp_path / 'snapshot.json.gz'
        monkeypatch.setattr(market_data, '_SNAPSHOT_DIR', str(tmp_path))
        monkeypatch.setattr(market_data, '_SNAPSHOT_PATH', str(snapshot_path))

        market_data._save_snapshot(sample_df)
        assert snapshot_path.exists()

        # 落盘内容可被独立解析
        with gzip.open(snapshot_path, 'rt', encoding='utf-8') as fh:
            payload = json.load(fh)
        assert len(payload['rows']) == 2

        market_data._stock_data_cache['df'] = None
        assert market_data.load_snapshot() is True
        assert len(market_data.get_stock_data()) == 2

    def test_expired_snapshot_is_ignored(self, tmp_path, monkeypatch, sample_df):
        snapshot_path = tmp_path / 'snapshot.json.gz'
        monkeypatch.setattr(market_data, '_SNAPSHOT_DIR', str(tmp_path))
        monkeypatch.setattr(market_data, '_SNAPSHOT_PATH', str(snapshot_path))
        monkeypatch.setattr(market_data, '_SNAPSHOT_MAX_AGE', 60)

        payload = {
            'saved_at': time.time() - 3600,
            'rows': sample_df.to_dict('records'),
        }
        with gzip.open(snapshot_path, 'wt', encoding='utf-8') as fh:
            json.dump(payload, fh)

        assert market_data.load_snapshot() is False
        assert market_data.get_stock_data() is None

    def test_missing_snapshot_is_safe(self, tmp_path, monkeypatch):
        monkeypatch.setattr(market_data, '_SNAPSHOT_PATH', str(tmp_path / 'nope.gz'))
        assert market_data.load_snapshot() is False


class TestRefreshOnce:
    def test_refresh_resets_loading_flag(self, monkeypatch, sample_df):
        """旧实现加载成功后不复位 loading，导致 data_status 永远“加载中”。"""
        def fake_load():
            market_data._stock_data_cache['df'] = sample_df
            market_data._stock_data_cache['last_update'] = time.time()

        monkeypatch.setattr(market_data, '_load_stock_data', fake_load)
        monkeypatch.setattr(market_data, '_save_snapshot', lambda df: None)

        assert market_data._refresh_once() is True
        assert market_data.stock_data_is_loading() is False
        assert market_data.get_stock_data() is not None

    def test_refresh_skips_when_already_loading(self, monkeypatch):
        market_data._stock_data_cache['loading'] = True
        called = []
        monkeypatch.setattr(market_data, '_load_stock_data', lambda: called.append(1))

        assert market_data._refresh_once() is False
        assert called == []


class TestEndpointsDoNotBlock:
    def test_screen_returns_preparing_message_quickly(self, client):
        start = time.time()
        response = client.get('/api/stock/screen?pe_max=20')
        elapsed = time.time() - start

        body = response.get_json()
        assert response.status_code == 200
        assert body['success'] is False
        assert '准备中' in body['error']
        assert body['retry_after'] == 10
        assert elapsed < 1.0

    def test_recommend_returns_preparing_message_quickly(self, client):
        start = time.time()
        body = client.get('/api/stock/recommend?count=5').get_json()
        elapsed = time.time() - start

        assert body['success'] is False
        assert elapsed < 1.0

    def test_error_message_when_load_failed(self, client):
        market_data._stock_data_cache['load_error'] = '上游接口全部失败'

        body = client.get('/api/stock/screen').get_json()

        assert body['success'] is False
        assert '暂时不可用' in body['error']
        assert body['detail'] == '上游接口全部失败'

    def test_data_status_reports_age_and_flags(self, client, sample_df):
        market_data._stock_data_cache['df'] = sample_df
        market_data._stock_data_cache['last_update'] = time.time() - 5

        body = client.get('/api/stock/data_status').get_json()

        assert body['loaded'] is True
        assert body['loading'] is False
        assert body['row_count'] == 2
        assert 4 <= body['age_seconds'] <= 6
        assert body['stale'] is False
        assert 'trading_time' in body
        assert body['refresh_interval'] >= 60

    def test_screen_serves_data_when_loaded(self, client, sample_df):
        market_data._stock_data_cache['df'] = sample_df
        market_data._stock_data_cache['last_update'] = time.time()

        body = client.get('/api/stock/screen?pe_max=30').get_json()

        assert body['success'] is True
        assert len(body['data']) == 2
        assert {row['code'] for row in body['data']} == {'600519', '000001'}
        assert body['total'] >= 1
