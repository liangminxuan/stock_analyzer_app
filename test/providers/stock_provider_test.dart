import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analyzer_app/providers/market_provider.dart';
import 'package:stock_analyzer_app/providers/stock_provider.dart';
import 'package:stock_analyzer_app/services/api_service.dart';

import '../helpers/fake_adapter.dart';

/// 生成 n 条 K线（收盘价 1..n），用于验证均线计算
String klineJson(int n) {
  final klines = <String>[];
  for (var i = 1; i <= n; i++) {
    klines.add('2026-09-${i.toString().padLeft(2, '0')},'
        '${i.toDouble()},${i.toDouble()},${i + 0.5},${i - 0.5},${1000 + i}');
  }
  return '{"rc":0,"data":{"code":"600519","klines":["${klines.join('","')}"]}}';
}

void main() {
  late StockApiService api;

  setUp(() {
    api = StockApiService();
    api.dio.httpClientAdapter = FakeAdapter((_) => textBody(''));
  });

  group('StockProvider', () {
    test('fetchKLineData 成功时写入数据并计算 MA5/MA10/MA20', () async {
      api.dio.httpClientAdapter = FakeAdapter((_) => textBody(klineJson(25)));

      final provider = StockProvider();
      await provider.fetchKLineData(code: '600519', period: 'day', limit: 25);

      expect(provider.error, isNull);
      expect(provider.klineData, hasLength(25));
      expect(provider.currentPeriod, 'day');

      final last = provider.klineData.last;
      // 收盘价 21..25 的均值
      expect(last.ma5, closeTo(23.0, 0.001));
      expect(last.ma10, closeTo(20.5, 0.001));
      expect(last.ma20, closeTo(15.5, 0.001));
      // 前 4 条不足 5 日均线
      expect(provider.klineData.first.ma5, isNull);
    });

    test('fetchKLineData 失败时清空数据并暴露错误（此前静默失败）', () async {
      api.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('boom', statusCode: 500),
      );

      final provider = StockProvider();
      await provider.fetchKLineData(code: '600519');

      expect(provider.error, isNotNull);
      expect(provider.klineData, isEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('fetchStockDetail 失败时置空当前股票并暴露可读错误', () async {
      api.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('boom', statusCode: 500),
      );

      final provider = StockProvider();
      await provider.fetchStockDetail('600519');

      expect(provider.currentStock, isNull);
      expect(provider.error, '行情数据获取失败，请检查网络后重试');
    });

    test('fetchStockDetail 成功时填充股票信息', () async {
      api.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody(
          tencentQuoteLine(code: '600519', name: '贵州茅台', price: 1274.89),
        ),
      );

      final provider = StockProvider();
      await provider.fetchStockDetail('600519');

      expect(provider.error, isNull);
      expect(provider.currentStock, isNotNull);
      expect(provider.currentStock!.currentPrice, closeTo(1274.89, 0.001));
    });
  });

  group('MarketProvider', () {
    test('指数接口失败时清空列表并暴露错误', () async {
      api.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('boom', statusCode: 500),
      );

      final provider = MarketProvider();
      await provider.fetchMarketIndices();

      expect(provider.indices, isEmpty);
      expect(provider.error, isNotNull);
    });

    test('热门股票接口失败时清空列表并暴露错误', () async {
      api.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('boom', statusCode: 500),
      );

      final provider = MarketProvider();
      await provider.fetchHotStocks();

      expect(provider.hotStocks, isEmpty);
      expect(provider.error, isNotNull);
    });
  });
}
