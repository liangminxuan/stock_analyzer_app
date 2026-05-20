import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';

/// 股票数据API服务 - 使用腾讯财经作为主要数据源
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
      responseType: ResponseType.bytes,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://gu.qq.com/',
      },
    ));
    _initialized = true;
    print('[API] 服务初始化完成 - 腾讯财经数据源');
  }

  /// GBK 解码
  String _decodeGbk(Uint8List bytes) {
    try {
      return gbk.decode(bytes);
    } catch (e) {
      try {
        return utf8.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  /// 发送 GET 请求并 GBK 解码
  Future<String> _fetchGbk(String url) async {
    final response = await _dio.get(url);
    return _decodeGbk(response.data as Uint8List);
  }

  /// 去掉市场前缀，获取纯代码
  String _pureCode(String code) {
    if (code.startsWith('sh') || code.startsWith('sz')) {
      return code.substring(2);
    }
    return code;
  }

  /// 获取腾讯格式的股票代码
  String _tencentCode(String code) {
    final pure = _pureCode(code);
    return pure.startsWith('6') || pure.startsWith('5') ? 'sh$pure' : 'sz$pure';
  }

  /// 获取市场标识
  String _market(String code) {
    final pure = _pureCode(code);
    return pure.startsWith('6') || pure.startsWith('5') ? 'sh' : 'sz';
  }

  // ==================== 预定义名称 ====================

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

  // ==================== 核心接口 ====================

  /// 解析腾讯单条数据
  Map<String, dynamic>? _parseTencentLine(String content, String code) {
    try {
      final fields = content.split('~');
      if (fields.length < 45) return null;

      final name = _stockNames[code] ?? fields[1];
      final currentPrice = double.tryParse(fields[3]) ?? 0;
      final prevClose = double.tryParse(fields[4]) ?? 0;
      final openPrice = double.tryParse(fields[5]) ?? 0;
      final volume = int.tryParse(fields[6]) ?? 0;
      // fields[31]=涨跌幅(带符号), fields[30]=涨跌额(带符号)
      final changePercent = double.tryParse(fields[31]) ?? 0;
      final change = double.tryParse(fields[30]) ?? 0;
      // fields[32]=最高, fields[33]=最低
      final high = double.tryParse(fields[32]) ?? 0;
      final low = double.tryParse(fields[33]) ?? 0;
      // fields[37]=总市值(元), fields[43]=市盈率
      final marketCap = double.tryParse(fields[37]) ?? 0;
      final pe = double.tryParse(fields[43]) ?? 0;

      // 五档买卖盘: fields[9~18]=买盘(价格,量), fields[19~28]=卖盘(价格,量)
      final bidPrices = <double>[];
      final bidVolumes = <int>[];
      final askPrices = <double>[];
      final askVolumes = <int>[];
      for (int i = 0; i < 5; i++) {
        bidPrices.add(double.tryParse(fields[9 + i * 2]) ?? 0);
        bidVolumes.add(int.tryParse(fields[10 + i * 2]) ?? 0);
        askPrices.add(double.tryParse(fields[19 + i * 2]) ?? 0);
        askVolumes.add(int.tryParse(fields[20 + i * 2]) ?? 0);
      }

      final pure = _pureCode(code);
      return {
        'code': pure,
        'name': name,
        'market': _market(code),
        'currentPrice': currentPrice,
        'previousClose': prevClose,
        'open': openPrice,
        'high': high,
        'low': low,
        'volume': volume,
        'turnover': 0.0,
        'change': change,
        'changePercent': changePercent,
        'marketCap': marketCap,
        'pe': pe,
        'bidPrices': bidPrices,
        'bidVolumes': bidVolumes,
        'askPrices': askPrices,
        'askVolumes': askVolumes,
      };
    } catch (e) {
      print('[API] 解析失败: $e');
      return null;
    }
  }

  /// 获取股票实时行情
  Future<Map<String, dynamic>> getStockQuote(String code) async {
    try {
      final tc = _tencentCode(code);
      final url = 'https://qt.gtimg.cn/q=$tc';
      print('[API] 请求: $url');

      final data = await _fetchGbk(url);
      final regex = RegExp(r'v_[^=]+="([^"]*)"');
      final match = regex.firstMatch(data);
      if (match == null) return _emptyQuote(code);

      final result = _parseTencentLine(match.group(1)!, code);
      if (result != null) {
        print('[API] 成功: ${result['name']} 价格=${result['currentPrice']} 涨跌=${result['changePercent']}%');
        return result;
      }
      return _emptyQuote(code);
    } catch (e) {
      print('[API] 行情失败: $code - $e');
      return _emptyQuote(code);
    }
  }

  /// 获取股票列表（热门股票）- 字段名统一用 currentPrice
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

      final tcCodes = codes.map((c) => _tencentCode(c)).join(',');
      final url = 'https://qt.gtimg.cn/q=$tcCodes';
      print('[API] 批量请求 ${codes.length} 只');

      final data = await _fetchGbk(url);
      final results = <Map<String, dynamic>>[];
      final regex = RegExp(r'v_([^=]+)="([^"]*)"');

      for (final match in regex.allMatches(data)) {
        final tcCode = match.group(1)!;
        final result = _parseTencentLine(match.group(2)!, tcCode);
        if (result != null) {
          results.add(result);
        }
      }

      print('[API] 获取 ${results.length} 条');
      return results.isEmpty ? _getDefaultHotStocks() : results;
    } catch (e) {
      print('[API] 列表失败: $e');
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
        final tcCode = match.group(1)!;
        final result = _parseTencentLine(match.group(2)!, tcCode);
        if (result != null) {
          final code = _pureCode(tcCode);
          results.add({
            'code': code,
            'name': _indexNames[code] ?? result['name'],
            'currentPoint': result['currentPrice'],
            'change': result['change'],
            'changePercent': result['changePercent'],
          });
        }
      }

      return results.isEmpty ? _defaultIndices() : results;
    } catch (e) {
      print('[API] 指数失败: $e');
      return _defaultIndices();
    }
  }

  /// 获取K线数据 - 自动处理市场前缀
  Future<List<Map<String, dynamic>>> getKLineData({
    required String code,
    String period = 'day',
    int count = 100,
  }) async {
    try {
      // 统一去掉市场前缀
      final pure = _pureCode(code);
      final mkt = _market(pure);
      final type = period == 'day' ? 'day' : period == 'week' ? 'week' : 'month';

      final url = 'https://web.ifzq.gtimg.cn/appstock/app/fwk/getkline'
          '?_var=mk_$mkt$pure'
          '&param=$mkt$pure,$type,,,$count,';

      print('[API] K线请求: $mkt$pure $type x$count');

      final response = await _dio.get(url);
      final data = _decodeGbk(response.data as Uint8List);

      final results = <Map<String, dynamic>>[];
      // 匹配 [时间,开盘,收盘,最高,最低,成交量,...]
      final regex = RegExp(r'\["?(\d{8})"?,([\d.]+),([\d.]+),([\d.]+),([\d.]+),(\d+)');

      for (final match in regex.allMatches(data)) {
        final timeStr = match.group(1)!;
        // 将 20240101 转为 2024-01-01
        final formattedTime = '${timeStr.substring(0,4)}-${timeStr.substring(4,6)}-${timeStr.substring(6,8)}';

        results.add({
          'time': formattedTime,
          'open': double.tryParse(match.group(2)!) ?? 0,
          'close': double.tryParse(match.group(3)!) ?? 0,
          'high': double.tryParse(match.group(4)!) ?? 0,
          'low': double.tryParse(match.group(5)!) ?? 0,
          'volume': int.tryParse(match.group(6)!) ?? 0,
        });
      }

      print('[API] K线获取 ${results.length} 条');
      return results;
    } catch (e) {
      print('[API] K线失败: $e');
      return [];
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
            'market': _market(entry.key),
          });
        }
      }
      if (results.length < 5 && keyword.length == 6) {
        final quote = await getStockQuote(keyword);
        if ((quote['currentPrice'] as num) > 0) {
          results.add(quote);
        }
      }
      return results.take(20).toList();
    } catch (e) {
      return [];
    }
  }

  // ==================== 默认数据 ====================

  Map<String, dynamic> _emptyQuote(String code) {
    final pure = _pureCode(code);
    return {
      'code': pure,
      'name': _stockNames[pure] ?? pure,
      'market': _market(pure),
      'currentPrice': 0.0,
      'previousClose': 0.0,
      'open': 0.0,
      'high': 0.0,
      'low': 0.0,
      'volume': 0,
      'turnover': 0.0,
      'change': 0.0,
      'changePercent': 0.0,
      'bidPrices': <double>[],
      'bidVolumes': <int>[],
      'askPrices': <double>[],
      'askVolumes': <int>[],
    };
  }

  List<Map<String, dynamic>> _getDefaultHotStocks() {
    return [
      {'code': '600519', 'name': '贵州茅台', 'market': 'sh', 'currentPrice': 1315.0, 'changePercent': -0.7, 'change': -9.2, 'previousClose': 1324.2},
      {'code': '601318', 'name': '中国平安', 'market': 'sh', 'currentPrice': 45.0, 'changePercent': 0.5, 'change': 0.22, 'previousClose': 44.78},
      {'code': '600036', 'name': '招商银行', 'market': 'sh', 'currentPrice': 32.0, 'changePercent': 0.3, 'change': 0.1, 'previousClose': 31.9},
      {'code': '000333', 'name': '美的集团', 'market': 'sz', 'currentPrice': 55.0, 'changePercent': 1.2, 'change': 0.66, 'previousClose': 54.34},
      {'code': '000651', 'name': '格力电器', 'market': 'sz', 'currentPrice': 38.0, 'changePercent': -0.5, 'change': -0.19, 'previousClose': 38.19},
    ];
  }

  List<Map<String, dynamic>> _defaultIndices() {
    return [
      {'code': '000001', 'name': '上证指数', 'currentPoint': 3100.0, 'change': 0, 'changePercent': 0},
      {'code': '399001', 'name': '深证成指', 'currentPoint': 9500.0, 'change': 0, 'changePercent': 0},
      {'code': '399006', 'name': '创业板指', 'currentPoint': 1800.0, 'change': 0, 'changePercent': 0},
    ];
  }
}
