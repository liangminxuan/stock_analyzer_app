import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analyzer_app/models/stock.dart';

void main() {
  group('Stock.fromQuote 解析', () {
    test('由现价与昨收计算涨跌', () {
      final stock = Stock.fromQuote({
        'code': '600519',
        'name': '贵州茅台',
        'market': 'sh',
        'currentPrice': 10.0,
        'previousClose': 9.5,
      });

      expect(stock.change, closeTo(0.5, 1e-9));
      expect(stock.changePercent, closeTo(5.263157, 1e-5));
    });

    test('昨收为 0 时涨跌幅为 0（不产生 Infinity）', () {
      final stock = Stock.fromQuote({
        'code': '600519',
        'previousClose': 0,
        'currentPrice': 10,
      });

      expect(stock.changePercent, 0.0);
      expect(stock.changePercent.isFinite, isTrue);
    });

    test('只给出 change/changePercent 时反推昨收', () {
      final stock = Stock.fromQuote({
        'code': '000001',
        'currentPrice': 11.2,
        'change': 0.2,
        'changePercent': 1.82,
      });

      expect(stock.change, closeTo(0.2, 1e-9));
      expect(stock.changePercent, closeTo(1.82, 1e-9));
      expect(stock.previousClose, closeTo(11.0, 1e-9));
    });

    test('字段为字符串时也能解析（旧实现会抛类型错误）', () {
      final stock = Stock.fromQuote({
        'code': '600519',
        'name': '贵州茅台',
        'currentPrice': '1274.89',
        'previousClose': '1288.00',
        'volume': '26573',
        'pe': '22.5',
      });

      expect(stock.currentPrice, closeTo(1274.89, 1e-9));
      expect(stock.previousClose, closeTo(1288.0, 1e-9));
      expect(stock.change, closeTo(-13.11, 1e-9));
      expect(stock.volume, 26573);
      expect(stock.peRatio, closeTo(22.5, 1e-9));
    });

    test('缺字段时给出安全默认值', () {
      final stock = Stock.fromQuote({'code': '600519'});

      expect(stock.currentPrice, 0.0);
      expect(stock.change, 0.0);
      expect(stock.changePercent, 0.0);
      expect(stock.volume, 0);
      expect(stock.name, '未知');
      expect(stock.bidPrices, isEmpty);
      expect(stock.askVolumes, isEmpty);
    });

    test('买卖五档含 int 元素时统一转成 double', () {
      final stock = Stock.fromQuote({
        'code': '600519',
        'bidPrices': [1274, 1273, 1272, 1271, 1270],
        'bidVolumes': [1, 2, 3, 4, 5],
      });

      expect(stock.bidPrices, [1274.0, 1273.0, 1272.0, 1271.0, 1270.0]);
      expect(stock.bidVolumes, [1, 2, 3, 4, 5]);
    });

    test('买卖五档混入非法元素时被过滤，不抛异常', () {
      final stock = Stock.fromQuote({
        'code': '600519',
        'bidPrices': [1274.0, 'oops', null],
      });

      expect(stock.bidPrices, [1274.0]);
    });
  });
}
