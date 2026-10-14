import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analyzer_app/models/stock.dart';
import 'package:stock_analyzer_app/providers/user_provider.dart';
import 'package:stock_analyzer_app/services/user_data_store.dart';

void main() {
  group('UserProvider 自选股', () {
    test('新增/去重/移除', () {
      final provider = UserProvider(store: InMemoryUserDataStore());

      provider.addToWatchlist(
        const StockItem(code: '600519', name: '贵州茅台', market: 'sh'),
      );
      provider.addToWatchlist(
        const StockItem(code: '600519', name: '贵州茅台', market: 'sh'),
      );
      expect(provider.watchlist, hasLength(1));
      expect(provider.isInWatchlist('600519'), isTrue);

      provider.removeFromWatchlist('600519');
      expect(provider.watchlist, isEmpty);
      expect(provider.isInWatchlist('600519'), isFalse);
    });

    test('重启后能恢复自选股（此前只存内存，杀进程即丢失）', () async {
      final store = InMemoryUserDataStore();

      final first = UserProvider(store: store);
      first.addToWatchlist(
        const StockItem(
          code: '000333',
          name: '美的集团',
          market: 'sz',
          price: 55.0,
          changePercent: 1.2,
        ),
      );
      // 等待异步持久化完成
      await Future<void>.delayed(Duration.zero);

      final second = UserProvider(store: store);
      await second.init();

      expect(second.initialized, isTrue);
      expect(second.watchlist, hasLength(1));
      expect(second.watchlist.first.code, '000333');
      expect(second.watchlist.first.name, '美的集团');
      expect(second.watchlist.first.price, closeTo(55.0, 0.001));
    });

    test('移除后重启不会复活', () async {
      final store = InMemoryUserDataStore();

      final first = UserProvider(store: store);
      first.addToWatchlist(
        const StockItem(code: '600519', name: '贵州茅台', market: 'sh'),
      );
      await Future<void>.delayed(Duration.zero);
      first.removeFromWatchlist('600519');
      await Future<void>.delayed(Duration.zero);

      final second = UserProvider(store: store);
      await second.init();

      expect(second.watchlist, isEmpty);
    });

    test('组合盈亏计算', () {
      final provider = UserProvider(store: InMemoryUserDataStore());
      provider.addToPortfolio(
        PortfolioItem(
          code: '600519',
          name: '贵州茅台',
          market: 'sh',
          shares: 100,
          avgCost: 1200,
          currentPrice: 1300,
        ),
      );

      expect(provider.totalPortfolioCost, closeTo(120000, 0.001));
      expect(provider.totalPortfolioValue, closeTo(130000, 0.001));
      expect(provider.totalPortfolioProfit, closeTo(10000, 0.001));
      expect(provider.totalPortfolioReturn, closeTo(8.3333, 0.01));
    });
  });
}
