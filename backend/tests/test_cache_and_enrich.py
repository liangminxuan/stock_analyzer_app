"""缓存与腾讯基本面补充的回归测试。

对应审计报告 P1-1（缓存只存时间戳，命中时返回未补全的数据）
与 P1-2（缓存无淘汰策略、无界增长）。
"""

import time

import pandas as pd

import cache_store
import market_data


class TestTTLCache:
    def test_set_then_get(self):
        cache_store.set_cached('k', {'v': 1}, timeout_seconds=60)
        assert cache_store.get_cached('k') == {'v': 1}

    def test_expired_entry_is_removed(self):
        cache_store.set_cached('k', 'v', timeout_seconds=0)
        time.sleep(0.01)
        assert cache_store.get_cached('k') is None
        # 过期条目应被清理，而不是留在字典里
        assert 'k' not in cache_store._cache

    def test_missing_key_returns_none(self):
        assert cache_store.get_cached('nope') is None

    def test_cache_is_bounded_by_lru(self):
        for i in range(cache_store._CACHE_MAX_ENTRIES + 10):
            cache_store.set_cached(f'k{i}', i, timeout_seconds=600)

        assert len(cache_store._cache) == cache_store._CACHE_MAX_ENTRIES
        # 最早写入的已被淘汰，最新的还在
        assert cache_store.get_cached('k0') is None
        assert cache_store.get_cached(f'k{cache_store._CACHE_MAX_ENTRIES + 9}') is not None


def _unfilled_df():
    return pd.DataFrame([
        {'code': '600519', 'name': '贵州茅台', 'pe': float('nan'), 'pb': float('nan'),
         'market_cap': float('nan'), 'turnover': float('nan')},
        {'code': '000001', 'name': '平安银行', 'pe': float('nan'), 'pb': float('nan'),
         'market_cap': float('nan'), 'turnover': float('nan')},
    ])


class TestEnrichCacheRegression:
    """旧实现在缓存命中时直接返回未补充的 df，这里锁定正确行为。"""

    def test_second_call_reuses_cached_fundamentals(self, monkeypatch):
        calls = []

        def fake_quote(codes):
            calls.append(list(codes))
            return {
                '600519': {'pe_ttm': 25.0, 'pb': 8.0, 'mcap_yi': 18000.0, 'turnover_pct': 0.5},
                '000001': {'pe_ttm': 6.5, 'pb': 0.6, 'mcap_yi': 2000.0, 'turnover_pct': 1.2},
            }

        monkeypatch.setattr(market_data, '_tencent_quote', fake_quote)

        first = market_data._enrich_with_tencent(_unfilled_df())
        second = market_data._enrich_with_tencent(_unfilled_df())

        # 只请求了一次腾讯接口（第二次命中缓存）
        assert len(calls) == 1
        # 两次都拿到补全后的数据（这正是旧实现丢掉的部分）
        assert first.loc[0, 'pe'] == 25.0
        assert second.loc[0, 'pe'] == 25.0
        assert second.loc[0, 'pb'] == 8.0
        assert second.loc[0, 'market_cap'] == 18000.0
        assert second.loc[1, 'pe'] == 6.5

    def test_existing_values_are_not_overwritten(self, monkeypatch):
        monkeypatch.setattr(
            market_data, '_tencent_quote',
            lambda codes: {'600519': {'pe_ttm': 99.0, 'pb': 99.0, 'mcap_yi': 99.0, 'turnover_pct': 9.9}},
        )
        df = _unfilled_df()
        df.loc[0, 'pe'] = 12.5

        result = market_data._enrich_with_tencent(df)

        assert result.loc[0, 'pe'] == 12.5   # 已有有效值不被覆盖
        assert result.loc[0, 'pb'] == 99.0   # 缺失值被补上

    def test_empty_tencent_response_keeps_df_untouched(self, monkeypatch):
        monkeypatch.setattr(market_data, '_tencent_quote', lambda codes: {})

        result = market_data._enrich_with_tencent(_unfilled_df())

        assert pd.isna(result.loc[0, 'pe'])
        # 没有数据时不应写入“假”缓存
        assert market_data._tencent_fundamentals_cache['data'] == {}
