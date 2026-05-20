import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';

/// 股票数据API服务 - 使用腾讯财经作为主要数据源
/// 腾讯接口稳定、免费、无需认证
class StockApiService {
  static final StockApiService _instance = StockApiService._internal();
  factory StockApiService() => _instance;
  StockApiService._internal();

  late Dio _dio;
  bool _initialized = false;

  Dio get dio {
    if (!_initialized) init();
    return _dio;
  }

  void init() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      responseType: ResponseType.bytes, // 用 bytes 接收，手动处理 GBK 编码
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://gu.qq.com/',
      },
    ));
    _initialized = true;
    print('[API] 服务初始化完成 - 使用腾讯财经数据源');
  }

  /// 将 GBK 编码的字节转为 UTF-8 字符串
  String _decodeGbk(Uint8List bytes) {
    try {
      // 尝试用 GBK 解码
      return gbk.decode(bytes);
    } catch (e) {
      // 如果 GBK 解码失败，回退到 UTF-8
      try {
        return utf8.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  // 预定义的股票名称（腾讯接口可能返回乱码，用此作为保底）
  static const Map<String, String> _stockNames = {
    '600519': '贵州茅台', '601318': '中国平安', '600036': '招商银行',
    '600276': '恒瑞医药', '601012': '隆基绿能', '600900': '长江电力',
    '601398': '工商银行', '600030': '中信证券', '601166': '兴业银行',
    '600887': '伊利股份', '000001': '平安银行', '000002': '万科A',
    '000333': '美的集团', '000651': '格力电器', '000858': '五粮液',
    '300750': '宁德时代', '300015': '爱尔眼科', '300059': '东方财富',
    '002594': '比亚迪', '002475': '立讯精密', '601888': '中国中免',
    '002415': '海康威视', '601288': '农业银行', '601939': '建设银行',
    '601988': '中国银行', '600000': '浦发银行', '002230': '科大讯飞',
    '300760': '迈瑞医疗', '603288': '海天味业', '600309': '万华化学',
    '002142': '宁波银行', '600809': '山西汾酒', '000568': '泸州老窖',
    '300124': '汇川技术', '601668': '中国建筑', '601857': '中国石油',
    '600028': '中国石化', '601728': '中国电信', '600050': '中国联通',
    '688981': '中芯国际', '688599': '天合光能', '688111': '金山办公',
  };

  static const Map<String, String> _indexNames = {
    '000001': '上证指数', '399001': '深证成指', '399006': '创业板指',
    '000016': '上证50', '000300': '沪深300',
  };

  // ==================== 腾讯财经接口 ====================

  /// 发送 HTTP GET 请求并返回 GBK 解码后的字符串
  Future<String> _fetchGbk(String url) async {
    final response = await _dio.get(url);
    return _decodeGbk(response.data as Uint8List);
  }

  /// 获取股票实时行情（腾讯财经）
  Future<Map<String, dynamic>> getStockQuote(String code) async {
    try {
      String marketCode = _getTencentCode(code);
      final url = 'https://qt.gtimg.cn/q=$marketCode';
      print('[API] 请求腾讯接口: $url');

      final data = await _fetchGbk(url);
      final result = _parseTencentData(data, code);
      if (result != null) {
        print('[API] 获取行情成功: ${result['name']} ${result['currentPrice']}');
        return result;
      }

      return _emptyQuote(code);
    } catch (e) {
      print('[API] 获取行情失败: $code - $e');
      return _emptyQuote(code);
    }
  }

  /// 解析腾讯财经数据
  Map<String, dynamic>? _parseTencentData(String data, String code) {
    try {
      final regex = RegExp(r'v_[^=]+="([^"]*)"');
      final match = regex.firstMatch(data);
      if (match == null) return null;

      final content = match.group(1)!;
      final fields = content.split('~');

      if (fields.length < 34) return null;

      // 腾讯数据字段解析
      // fields[1] = 名称（可能乱码，用预定义名称保底）
      final apiName = fields[1];
      final name = _stockNames[code] ?? apiName;
      final currentPrice = double.tryParse(fields[3]) ?? 0;
      final prevClose = double.tryParse(fields[4]) ?? 0;
      final openPrice = double.tryParse(fields[5]) ?? 0;
      final volume = int.tryParse(fields[6]) ?? 0;
      final high = double.tryParse(fields[32]) ?? 0;
      final low = double.tryParse(fields[33]) ?? 0;
      // fields[31] = 涨跌幅（已经带符号，如 -7.36 或 +0.50）
      final changePercent = double.tryParse(fields[31]) ?? 0;
      // fields[30] = 涨跌额（已经带符号）
      final change = double.tryParse(fields[30]) ?? 0;

      return {
        'code': code,
        'name': name,
        'market': code.startsWith('6') ? 'sh' : 'sz',
        'currentPrice': currentPrice,
        'previousClose': prevClose,
        'open': openPrice,
        'high': high,
        'low': low,
        'volume': volume,
        'turnover': 0.0,
        'change': change,
        'changePercent': changePercent,
      };
    } catch (e) {
      print('[API] 解析腾讯数据失败: $e');
      return null;
    }
  }

  /// 获取股票列表（热门股票）
  Future<List<Map<String, dynamic>>> getStockList({int page = 1, int pageSize = 20}) async {
    try {
      final hotCodes = [
        '600519', '601318', '600036', '000333', '000651',
        '300750', '002594', '601398', '600030', '601166',
        '000858', '600887', '300015', '002475', '601888',
        '002415', '601288', '601939', '601988', '600000',
        '000001', '000002', '300059', '603288', '600309',
        '002142', '600809', '300124', '601668', '601857',
      ];

      final codes = hotCodes.skip((page - 1) * pageSize).take(pageSize).toList();
      if (codes.isEmpty) return [];

      final tencentCodes = codes.map(_getTencentCode).join(',');
      final url = 'https://qt.gtimg.cn/q=$tencentCodes';
      print('[API] 批量请求: $url');

      final data = await _fetchGbk(url);

      final results = <Map<String, dynamic>>[];
      final regex = RegExp(r'v_([^=]+)="([^"]*)"');

      for (final match in regex.allMatches(data)) {
        final marketCode = match.group(1)!;
        final content = match.group(2)!;
        final fields = content.split('~');

        if (fields.length >= 34) {
          final code = marketCode.replaceAll(RegExp(r'^sh|^sz'), '');
          final name = _stockNames[code] ?? fields[1];
          final currentPrice = double.tryParse(fields[3]) ?? 0;
          final changePercent = double.tryParse(fields[31]) ?? 0;

          results.add({
            'code': code,
            'name': name,
            'market': code.startsWith('6') ? 'sh' : 'sz',
            'price': currentPrice,
            'changePercent': changePercent,
            'volume': int.tryParse(fields[6]) ?? 0,
            'high': double.tryParse(fields[32]) ?? 0,
            'low': double.tryParse(fields[33]) ?? 0,
            'open': double.tryParse(fields[5]) ?? 0,
          });
        }
      }

      print('[API] 获取到 ${results.length} 条股票数据');
      return results;
    } catch (e) {
      print('[API] 获取股票列表失败: $e');
      return _getDefaultHotStocks();
    }
  }

  /// 获取市场指数
  Future<List<Map<String, dynamic>>> getMarketIndices() async {
    try {
      final indices = ['sh000001', 'sz399001', 'sz399006'];
      final url = 'https://qt.gtimg.cn/q=${indices.join(',')}';

      final data = await _fetchGbk(url);

      final results = <Map<String, dynamic>>[];
      final regex = RegExp(r'v_([^=]+)="([^"]*)"');

      for (final match in regex.allMatches(data)) {
        final marketCode = match.group(1)!;
        final content = match.group(2)!;
        final fields = content.split('~');

        if (fields.length >= 34) {
          final code = marketCode.replaceAll(RegExp(r'^sh|^sz'), '');
          // fields[31] 涨跌幅已带符号
          final changePercent = double.tryParse(fields[31]) ?? 0;
          // fields[30] 涨跌额已带符号
          final change = double.tryParse(fields[30]) ?? 0;

          results.add({
            'code': code,
            'name': _indexNames[code] ?? code,
            'currentPoint': double.tryParse(fields[3]) ?? 0,
            'change': change,
            'changePercent': changePercent,
          });
        }
      }

      return results;
    } catch (e) {
      print('[API] 获取指数失败: $e');
      return [
        {'code': '000001', 'name': '上证指数', 'currentPoint': 3100.0, 'change': 0, 'changePercent': 0},
        {'code': '399001', 'name': '深证成指', 'currentPoint': 9500.0, 'change': 0, 'changePercent': 0},
        {'code': '399006', 'name': '创业板指', 'currentPoint': 1800.0, 'change': 0, 'changePercent': 0},
      ];
    }
  }

  /// 搜索股票
  Future<List<Map<String, dynamic>>> searchStocks(String keyword) async {
    try {
      final results = <Map<String, dynamic>>[];

      for (final entry in _stockNames.entries) {
        if (entry.key.contains(keyword) || entry.value.contains(keyword)) {
          results.add({
            'code': entry.key,
            'name': entry.value,
            'market': entry.key.startsWith('6') ? 'sh' : 'sz',
          });
        }
      }

      if (results.length < 5 && keyword.length == 6) {
        final quote = await getStockQuote(keyword);
        if (quote['currentPrice'] > 0) {
          results.add(quote);
        }
      }

      return results.take(20).toList();
    } catch (e) {
      print('[API] 搜索失败: $e');
      return [];
    }
  }

  /// 获取K线数据
  Future<List<Map<String, dynamic>>> getKLineData({
    required String code,
    String period = 'day',
    int count = 100,
  }) async {
    try {
      final market = code.startsWith('6') ? 'sh' : 'sz';
      final type = period == 'day' ? 'day' : period == 'week' ? 'week' : 'month';

      final url = 'https://web.ifzq.gtimg.cn/appstock/app/fwk/getkline'
          '?_var=mk_$market$code'
          '&param=$market$code,$type,,,$count,';

      final response = await _dio.get(url);
      final data = _decodeGbk(response.data as Uint8List);

      final results = <Map<String, dynamic>>[];
      final regex = RegExp(r'\[(\d+),([\d.]+),([\d.]+),([\d.]+),([\d.]+),(\d+),');

      for (final match in regex.allMatches(data)) {
        results.add({
          'time': match.group(1)!,
          'open': double.tryParse(match.group(2)!) ?? 0,
          'close': double.tryParse(match.group(3)!) ?? 0,
          'high': double.tryParse(match.group(4)!) ?? 0,
          'low': double.tryParse(match.group(5)!) ?? 0,
          'volume': int.tryParse(match.group(6)!) ?? 0,
        });
      }

      return results;
    } catch (e) {
      print('[API] 获取K线失败: $e');
      return [];
    }
  }

  // ==================== 辅助方法 ====================

  String _getTencentCode(String code) {
    if (code.startsWith('sh') || code.startsWith('sz')) {
      return code;
    }
    return code.startsWith('6') || code.startsWith('5') ? 'sh$code' : 'sz$code';
  }

  Map<String, dynamic> _emptyQuote(String code) {
    return {
      'code': code,
      'name': _stockNames[code] ?? code,
      'market': code.startsWith('6') ? 'sh' : 'sz',
      'currentPrice': 0.0,
      'previousClose': 0.0,
      'open': 0.0,
      'high': 0.0,
      'low': 0.0,
      'volume': 0,
      'turnover': 0.0,
      'change': 0.0,
      'changePercent': 0.0,
    };
  }

  List<Map<String, dynamic>> _getDefaultHotStocks() {
    return [
      {'code': '600519', 'name': '贵州茅台', 'market': 'sh', 'price': 1315.0, 'changePercent': -0.7},
      {'code': '601318', 'name': '中国平安', 'market': 'sh', 'price': 45.0, 'changePercent': 0.5},
      {'code': '600036', 'name': '招商银行', 'market': 'sh', 'price': 32.0, 'changePercent': 0.3},
      {'code': '000333', 'name': '美的集团', 'market': 'sz', 'price': 55.0, 'changePercent': 1.2},
      {'code': '000651', 'name': '格力电器', 'market': 'sz', 'price': 38.0, 'changePercent': -0.5},
    ];
  }
}
