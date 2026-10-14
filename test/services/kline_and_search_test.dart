import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analyzer_app/services/api_exception.dart';
import 'package:stock_analyzer_app/services/api_service.dart';

import '../helpers/fake_adapter.dart';

void main() {
  late StockApiService service;

  setUp(() {
    service = StockApiService();
    service.dio.httpClientAdapter = FakeAdapter((_) => textBody(''));
  });

  group('getKLineData K线', () {
    test('解析东财 K线 JSON', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody(
          '{"rc":0,"data":{"code":"600519","klines":'
          '["2026-10-09,1252.90,1255.79,1258.00,1242.00,25168",'
          '"2026-10-10,1255.00,1260.10,1265.00,1250.00,30123"]}}',
        ),
      );

      final klines = await service.getKLineData(code: '600519', count: 2);

      expect(klines, hasLength(2));
      expect(klines.first['time'], '2026-10-09');
      expect(klines.first['open'], closeTo(1252.90, 0.001));
      expect(klines.first['close'], closeTo(1255.79, 0.001));
      expect(klines.first['volume'], 25168);
    });

    test('无 klines 字段时返回空列表', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('{"rc":0,"data":null}'),
      );

      expect(await service.getKLineData(code: '600519'), isEmpty);
    });

    test('网络异常时抛出 ApiException', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('boom', statusCode: 502),
      );

      await expectLater(
        service.getKLineData(code: '600519'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('searchStocks 搜索', () {
    test('解码 \\uXXXX 并过滤非 A 股', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody(
          'v_hint="sh~600519~\\u8d35\\u5dde\\u8305\\u53f0~gzmt~GP-A'
          '^sz~159915~\\u521b\\u4e1a\\u677fETF~cybetf~JJ";',
        ),
      );

      final results = await service.searchStocks('茅台');

      expect(results, hasLength(1));
      expect(results.first['code'], '600519');
      expect(results.first['name'], '贵州茅台');
    });

    test('搜索接口异常时返回本地匹配结果（不抛异常、不返回假数据）', () async {
      service.dio.httpClientAdapter = FakeAdapter(
        (_) => textBody('oops', statusCode: 500),
      );

      final results = await service.searchStocks('600519');

      expect(results, hasLength(1));
      expect(results.first['name'], '贵州茅台');
    });
  });
}
