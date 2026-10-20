import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analyzer_app/models/stock.dart';
import 'package:stock_analyzer_app/utils/num_utils.dart';

void main() {
  group('asDouble 安全数值转换', () {
    test('接受 int / double / 数字字符串', () {
      expect(asDouble(5), 5.0);
      expect(asDouble(5.26), 5.26);
      expect(asDouble('3.14'), 3.14);
    });

    test('null 与非法值走 fallback', () {
      expect(asDouble(null), 0.0);
      expect(asDouble('-'), 0.0);
      expect(asDouble('abc'), 0.0);
      expect(asDouble(null, fallback: -1), -1.0);
    });

    test('回归：JSON 里为 int 时不再抛 int is not a subtype of double', () {
      // 旧写法 `(json['change_percent'] ?? 0) as double` 在这里会抛异常
      expect(() => asDouble(5), returnsNormally);
      expect(asDouble(5), 5.0);
    });
  });

  group('asInt 安全数值转换', () {
    test('接受 int / double / 数字字符串', () {
      expect(asInt(5), 5);
      expect(asInt(5.8), 5);
      expect(asInt('42'), 42);
    });

    test('null 与非法值走 fallback', () {
      expect(asInt(null), 0);
      expect(asInt('--'), 0);
      expect(asInt(null, fallback: 7), 7);
    });
  });

  group('asList / asMap', () {
    test('asList 过滤掉类型不符的元素', () {
      final raw = [
        {'code': '600519'},
        'oops',
        null,
      ];
      final list = asList<Map<String, dynamic>>(raw);
      expect(list, hasLength(1));
      expect(list.first['code'], '600519');
    });

    test('asList 对 null / 非 List 返回空列表', () {
      expect(asList<dynamic>(null), isEmpty);
      expect(asList<dynamic>('not-a-list'), isEmpty);
    });

    test('asMap 兼容 Map<dynamic, dynamic>', () {
      final map = asMap(<dynamic, dynamic>{'a': 1});
      expect(map, {'a': 1});
      expect(asMap(null), isNull);
      expect(asMap('x'), isNull);
    });
  });

  group('模型解析对 int 字段的兼容（后端 Python 可能返回 int）', () {
    test('Stock.fromJson 接受整数价格/成交量', () {
      final stock = Stock.fromJson({
        'code': '600519',
        'name': '贵州茅台',
        'market': 'sh',
        'currentPrice': 1274,   // int
        'previousClose': 1288,  // int
        'changePercent': 5,     // int
        'volume': 26573,        // int
      });

      expect(stock.currentPrice, 1274.0);
      expect(stock.previousClose, 1288.0);
      expect(stock.changePercent, 5.0);
      expect(stock.volume, 26573);
    });

    test('volume 为 double 时也能解析（旧写法会崩）', () {
      final stock = Stock.fromJson({
        'code': '600519',
        'name': '贵州茅台',
        'market': 'sh',
        'volume': 26573.0,      // double
      });

      expect(stock.volume, 26573);
    });
  });
}
