import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analyzer_app/services/api_exception.dart';
import 'package:stock_analyzer_app/services/api_service.dart';

import '../helpers/fake_adapter.dart';

void main() {
  late StockApiService service;

  setUp(() {
    service = StockApiService();
    // 每个用例都替换适配器，杜绝真实网络请求
    service.dio.httpClientAdapter = FakeAdapter(
      (_) => textBody(tencentQuoteLine(code: '600519')),
    );
  });

  group('getStockQuote 行情解析', () {
    test('正常响应时解析出价格、涨跌与买卖五档', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody(
          tencentQuoteLine(
            code: '600519',
            name: '贵州茅台',
            price: 1274.89,
            previousClose: 1288.00,
            change: -13.11,
            changePercent: -1.02,
            high: 1288.48,
            low: 1268.11,
          ),
        ),
      );

      final quote = await service.getStockQuote('600519');

      expect(quote['code'], '600519');
      expect(quote['market'], 'sh');
      expect(quote['currentPrice'], closeTo(1274.89, 0.001));
      expect(quote['previousClose'], closeTo(1288.00, 0.001));
      expect(quote['change'], closeTo(-13.11, 0.001));
      expect(quote['changePercent'], closeTo(-1.02, 0.001));
      expect(quote['high'], closeTo(1288.48, 0.001));
      expect(quote['low'], closeTo(1268.11, 0.001));
      expect((quote['bidPrices'] as List).length, 5);
      expect((quote['askVolumes'] as List).length, 5);
    });

    test('名称缺失时通过 UTF-8 搜索接口补全（不再显示乱码/代码）', () async {
      service.dio.httpClientAdapter = FakeAdapter((options) {
        if (options.uri.host.contains('smartbox')) {
          return textBody(
            'v_hint="sz~000777~\\u4e2d\\u6838\\u79d1\\u6280~zhkj~GP-A";',
          );
        }
        return textBody(tencentQuoteLine(code: '000777', name: '乱码'));
      });

      final quote = await service.getStockQuote('000777');

      expect(quote['name'], '中核科技');
    });

    test('HTTP 500 时抛出 ApiException，绝不返回硬编码价格', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('error', statusCode: 500),
      );

      await expectLater(
        service.getStockQuote('600519'),
        throwsA(isA<ApiException>()),
      );
    });

    test('响应格式异常时抛出 ApiException', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('not-a-quote'),
      );

      await expectLater(
        service.getStockQuote('600519'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('getStockList 热门股票', () {
    test('解析批量行情并补全缺失名称', () async {
      service.dio.httpClientAdapter = FakeAdapter((options) {
        if (options.uri.host.contains('smartbox')) {
          return textBody(
            'v_hint="sz~000777~\\u4e2d\\u6838\\u79d1\\u6280~zhkj~GP-A";',
          );
        }
        return textBody(
          tencentQuoteLine(code: '600519', name: '乱码', price: 1274.89) +
              tencentQuoteLine(code: '000777', name: '乱码', price: 8.88),
        );
      });

      final list = await service.getStockList();

      expect(list.length, 2);
      expect(list.first['code'], '600519');
      // 预定义表命中，名称不应是乱码
      expect(list.first['name'], '贵州茅台');
      // 预定义表未命中，走搜索接口补全
      expect(list.last['name'], '中核科技');
    });

    test('返回空数据时抛出 ApiException（此前返回假行情）', () async {
      service.dio.httpClientAdapter = FakeAdapter((_) => textBody(''));

      await expectLater(service.getStockList(), throwsA(isA<ApiException>()));
    });
  });

  group('getMarketIndices 大盘指数', () {
    test('解析指数点位与涨跌幅', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody(
          tencentQuoteLine(
            code: '000001',
            name: '上证指数',
            price: 3100.5,
            change: 12.3,
            changePercent: 0.4,
          ),
        ),
      );

      final indices = await service.getMarketIndices();

      expect(indices, hasLength(1));
      expect(indices.first['name'], '上证指数');
      expect(indices.first['currentPoint'], closeTo(3100.5, 0.001));
      expect(indices.first['changePercent'], closeTo(0.4, 0.001));
    });

    test('空数据时抛出 ApiException（此前返回 3100 假点位）', () async {
      service.dio.httpClientAdapter = FakeAdapter((_) => textBody(''));

      await expectLater(
        service.getMarketIndices(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
