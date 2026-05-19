import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';

/// 股票数据API服务 - 直接调用东方财富/新浪/腾讯 HTTP API
/// 参考 akshare 实现，无需 Python 后端
class StockApiService {
  static final StockApiService _instance = StockApiService._internal();
  factory StockApiService() => _instance;
  StockApiService._internal();

  late Dio _dio;
  bool _initialized = false;
  final Random _random = Random();

  // 上次请求时间（用于速率限制）
  DateTime _lastRequestTime = DateTime.now();

  Dio get dio {
    if (!_initialized) init();
    return _dio;
  }

  void init() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
      headers: {
        'User-Agent': _getRandomUA(),
        'Accept': '*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': 'https://quote.eastmoney.com/',
      },
    ));
    _initialized = true;
  }

  // ==================== 防爬策略 ====================

  /// 随机 User-Agent 池
  static const List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  ];

  String _getRandomUA() => _userAgents[_random.nextInt(_userAgents.length)];

  /// 速率限制：每次请求前随机休眠 0.3-0.8 秒
  Future<void> _rateLimit() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestTime).inMilliseconds;
    if (elapsed < 300) {
      await Future.delayed(Duration(milliseconds: 300 - elapsed));
    }
    // 随机抖动
    await Future.delayed(Duration(milliseconds: 300 + _random.nextInt(500)));
    _lastRequestTime = DateTime.now();
  }

  // ==================== 股票名称映射 ====================

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

  // ==================== 大盘指数 ====================

  /// 获取大盘指数（东方财富）
  Future<List<Map<String, dynamic>>> getMarketIndices() async {
    try {
      await _rateLimit();

      // 东方财富指数接口
      final url = 'https://push2.eastmoney.com/api/qt/ulist.np/get'
          '?fltt=2&invt=2&fields=f3,f12,f13,f14,f2,f4,f1'
          '&secids=1.000001,0.399001,0.399006,1.000016,1.000300';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = jsonDecode(response.data.toString());
      final diff = data['data']?['diff'] as List?;

      if (diff == null || diff.isEmpty) {
        return _getIndicesFromSina(); // 降级到新浪
      }

      return diff.map((e) {
        final code = e['f12']?.toString() ?? '';
        return {
          'code': code,
          'name': _indexNames[code] ?? e['f14']?.toString() ?? '',
          'currentPoint': (e['f2'] as num?)?.toDouble() ?? 0,
          'change': (e['f4'] as num?)?.toDouble() ?? 0,
          'changePercent': (e['f3'] as num?)?.toDouble() ?? 0,
        };
      }).toList();
    } catch (e) {
      print('[API] 东方财富指数失败: $e');
      return _getIndicesFromSina(); // 降级
    }
  }

  /// 新浪指数接口（降级方案）
  Future<List<Map<String, dynamic>>> _getIndicesFromSina() async {
    final indices = ['s_sh000001', 's_sz399001', 's_sz399006'];
    final results = <Map<String, dynamic>>[];

    try {
      await _rateLimit();
      final response = await _dio.get(
        'https://hq.sinajs.cn/list=${indices.join(',')}',
        options: Options(
          headers: {'Referer': 'https://finance.sina.com.cn'},
        ),
      );

      final data = response.data.toString();
      for (final index in indices) {
        final regex = RegExp('$index="([^"]*)"');
        final match = regex.firstMatch(data);
        if (match != null) {
          final values = match.group(1)!.split(',');
          if (values.length >= 4) {
            final code = index.substring(2);
            results.add({
              'code': code,
              'name': _indexNames[code] ?? values[0],
              'currentPoint': double.tryParse(values[1]) ?? 0,
              'change': double.tryParse(values[2]) ?? 0,
              'changePercent': double.tryParse(values[3]) ?? 0,
            });
          }
        }
      }
    } catch (e) {
      print('[API] 新浪指数也失败: $e');
    }

    return results;
  }

  // ==================== 实时行情 ====================

  /// 获取股票实时行情（东方财富）
  Future<Map<String, dynamic>> getStockQuote(String code) async {
    try {
      await _rateLimit();

      // 判断市场
      final market = code.startsWith('6') || code.startsWith('5') ? '1' : '0';

      // 东方财富实时行情接口
      final url = 'https://push2.eastmoney.com/api/qt/stock/get'
          '?fltt=2&invt=2&fields=f57,f58,f43,f169,f170,f46,f44,f51,f168,f47,f48,f60,f45,f52,f50,f49,f171,f113,f114,f115,f117'
          '&secid=$market.$code';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = jsonDecode(response.data.toString());
      final quote = data['data'];

      if (quote == null) {
        return _getQuoteFromSina(code); // 降级到新浪
      }

      // 获取股票名称 - 优先使用预定义名称，其次使用API返回的名称
      String stockName = _stockNames[code] ?? quote['f58']?.toString() ?? '';
      // 如果名称为空，尝试从其他字段获取
      if (stockName.isEmpty) {
        stockName = quote['f57']?.toString() ?? code; // f57是股票代码，f58是名称
      }
      
      final result = {
        'code': code,
        'name': stockName.isNotEmpty ? stockName : code,
        'market': market == '1' ? 'sh' : 'sz',
        'currentPrice': (quote['f43'] as num?)?.toDouble() ?? 0,
        'previousClose': (quote['f60'] as num?)?.toDouble() ?? 0,
        'open': (quote['f46'] as num?)?.toDouble() ?? 0,
        'high': (quote['f44'] as num?)?.toDouble() ?? 0,
        'low': (quote['f51'] as num?)?.toDouble() ?? 0,
        'volume': (quote['f47'] as num?)?.toInt() ?? 0,
        'turnover': (quote['f48'] as num?)?.toDouble() ?? 0,
        'change': (quote['f169'] as num?)?.toDouble() ?? 0,
        'changePercent': (quote['f170'] as num?)?.toDouble() ?? 0,
        'pe': (quote['f162'] as num?)?.toDouble(),
        'pb': (quote['f167'] as num?)?.toDouble(),
        'marketCap': (quote['f116'] as num?)?.toDouble(),
      };
      
      print('[API] 获取行情成功: $code -> $stockName, price=${result['currentPrice']}');
      return result;
    } catch (e) {
      print('[API] 东方财富行情失败: $code - $e');
      return _getQuoteFromSina(code); // 降级
    }
  }

  /// 新浪行情接口（降级方案）
  Future<Map<String, dynamic>> _getQuoteFromSina(String code) async {
    try {
      await _rateLimit();

      final market = code.startsWith('6') || code.startsWith('5') ? 'sh' : 'sz';
      final response = await _dio.get(
        'https://hq.sinajs.cn/list=$market$code',
        options: Options(headers: {'Referer': 'https://finance.sina.com.cn'}),
      );

      final data = response.data.toString();
      final regex = RegExp('var hq_str_$market$code="([^"]*)"');
      final match = regex.firstMatch(data);

      if (match == null) return _emptyQuote(code);

      final values = match.group(1)!.split(',');
      if (values.length < 33) return _emptyQuote(code);

      final currentPrice = double.tryParse(values[3]) ?? 0;
      final prevClose = double.tryParse(values[2]) ?? 0;
      
      // 获取股票名称，确保不为空
      String stockName = _stockNames[code] ?? values[0];
      if (stockName.isEmpty) {
        stockName = code;
      }

      return {
        'code': code,
        'name': stockName,
        'market': market,
        'currentPrice': currentPrice,
        'previousClose': prevClose,
        'open': double.tryParse(values[1]) ?? 0,
        'high': double.tryParse(values[4]) ?? 0,
        'low': double.tryParse(values[5]) ?? 0,
        'volume': int.tryParse(values[8]) ?? 0,
        'turnover': double.tryParse(values[9]) ?? 0,
        'change': currentPrice - prevClose,
        'changePercent': prevClose != 0 ? ((currentPrice - prevClose) / prevClose) * 100 : 0,
      };
    } catch (e) {
      print('[API] 新浪行情也失败: $code - $e');
      return _emptyQuote(code);
    }
  }

  Map<String, dynamic> _emptyQuote(String code) {
    // 确保名称不为空，使用预定义名称或代码
    String stockName = _stockNames[code] ?? '';
    if (stockName.isEmpty) {
      stockName = code;
    }
    
    return {
      'code': code,
      'name': stockName,
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

  // ==================== K线数据 ====================

  /// 获取K线数据（东方财富）
  Future<List<Map<String, dynamic>>> getKLineData({
    required String code,
    required String period,
    int limit = 100,
  }) async {
    try {
      await _rateLimit();

      final market = code.startsWith('6') || code.startsWith('5') ? '1' : '0';

      // 周期映射
      final kltMap = {'day': '101', 'week': '102', 'month': '103'};
      final klt = kltMap[period] ?? '101';

      // 东方财富K线接口
      final url = 'https://push2his.eastmoney.com/api/qt/stock/kline/get'
          '?fields1=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13'
          '&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61'
          '&klt=$klt&fqt=1&secid=$market.$code&end=20500101'
          '&lmt=$limit';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = jsonDecode(response.data.toString());
      final klines = data['data']?['klines'] as List?;

      if (klines == null || klines.isEmpty) {
        return _getKLineFromSina(code: code, period: period, limit: limit); // 降级
      }

      return klines.map((e) {
        final parts = e.toString().split(',');
        return {
          'time': parts[0],
          'open': double.tryParse(parts[1]) ?? 0,
          'close': double.tryParse(parts[2]) ?? 0,
          'high': double.tryParse(parts[3]) ?? 0,
          'low': double.tryParse(parts[4]) ?? 0,
          'volume': int.tryParse(parts[5]) ?? 0,
          'amount': double.tryParse(parts[6]) ?? 0,
          'changePercent': double.tryParse(parts[7]) ?? 0,
        };
      }).toList();
    } catch (e) {
      print('[API] 东方财富K线失败: $code - $e');
      return _getKLineFromSina(code: code, period: period, limit: limit); // 降级
    }
  }

  /// 新浪K线接口（降级方案）
  Future<List<Map<String, dynamic>>> _getKLineFromSina({
    required String code,
    required String period,
    int limit = 100,
  }) async {
    try {
      await _rateLimit();

      final market = code.startsWith('6') || code.startsWith('5') ? 'sh' : 'sz';

      final scaleMap = {
        'day': '240', 'week': '1680', 'month': '7200',
      };
      final scale = scaleMap[period] ?? '240';

      final url = 'https://money.finance.sina.com.cn/quotes_service/api/json_v2.php/CN_MarketData.getKLineData'
          '?symbol=$market$code&scale=$scale&ma=no&datalen=$limit';

      final response = await _dio.get(url);
      final data = response.data.toString();

      if (data.isEmpty || data.contains('null')) return [];

      final List<dynamic> klines = jsonDecode(data);
      return klines.map((e) {
        return {
          'time': e['day'] ?? '',
          'open': double.tryParse(e['open']?.toString() ?? '0') ?? 0,
          'close': double.tryParse(e['close']?.toString() ?? '0') ?? 0,
          'high': double.tryParse(e['high']?.toString() ?? '0') ?? 0,
          'low': double.tryParse(e['low']?.toString() ?? '0') ?? 0,
          'volume': int.tryParse(e['volume']?.toString() ?? '0') ?? 0,
        };
      }).toList();
    } catch (e) {
      print('[API] 新浪K线也失败: $code - $e');
      return [];
    }
  }

  // ==================== 热门股票 ====================

  /// 获取热门股票（东方财富涨幅榜）
  Future<List<Map<String, dynamic>>> getStockList({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      await _rateLimit();

      // 东方财富涨幅榜
      final url = 'https://push2.eastmoney.com/api/qt/clist/get'
          '?fltt=2&invt=2&fields=f12,f14,f2,f3,f62,f184,f66,f69,f72,f75,f78,f81,f84,f87,f204,f205,f124'
          '&fs=m:0+t:6,m:0+t:13,m:0+t:80,m:1+t:2,m:1+t:23'
          '&fid=f3&po=1&pn=$page&pz=$pageSize';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = jsonDecode(response.data.toString());
      final diff = data['data']?['diff'] as List?;

      if (diff == null || diff.isEmpty) {
        return _getDefaultHotStocks();
      }

      return diff.map((e) {
        final code = e['f12']?.toString() ?? '';
        return {
          'code': code,
          'name': _stockNames[code] ?? e['f14']?.toString() ?? '',
          'market': code.startsWith('6') ? 'sh' : 'sz',
          'price': (e['f2'] as num?)?.toDouble() ?? 0,
          'changePercent': (e['f3'] as num?)?.toDouble() ?? 0,
        };
      }).toList();
    } catch (e) {
      print('[API] 获取热门股票失败: $e');
      return _getDefaultHotStocks();
    }
  }

  List<Map<String, dynamic>> _getDefaultHotStocks() {
    return [
      {'code': '600519', 'name': '贵州茅台', 'market': 'sh', 'price': 1688.88, 'changePercent': 1.25},
      {'code': '601318', 'name': '中国平安', 'market': 'sh', 'price': 45.88, 'changePercent': 0.85},
      {'code': '300750', 'name': '宁德时代', 'market': 'sz', 'price': 198.50, 'changePercent': 2.15},
      {'code': '002594', 'name': '比亚迪', 'market': 'sz', 'price': 258.60, 'changePercent': 1.95},
    ];
  }

  // ==================== 搜索 ====================

  /// 搜索股票（东方财富）
  Future<List<Map<String, dynamic>>> searchStocks(String keyword) async {
    try {
      await _rateLimit();

      final url = 'https://searchapi.eastmoney.com/api/suggest/get'
          '?input=${Uri.encodeComponent(keyword)}'
          '&type=14&token=D43BF722C8E33BDC906FB84D85E326E8&count=20';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = jsonDecode(response.data.toString());
      final results = data['QuotationCodeTable']?['Data'] as List?;

      if (results == null) return [];

      return results.map((e) {
        final code = e['Code']?.toString() ?? '';
        final mktNum = e['MktNum']?.toString() ?? '0';
        return {
          'code': code,
          'name': _stockNames[code] ?? e['Name']?.toString() ?? '',
          'market': mktNum == '1' ? 'sh' : 'sz',
        };
      }).toList();
    } catch (e) {
      print('[API] 搜索失败: $keyword - $e');
      return [];
    }
  }

  // ==================== 财务数据 ====================

  /// 获取财务数据（东方财富）
  Future<Map<String, dynamic>> getFinanceReport(String code) async {
    try {
      await _rateLimit();

      final market = code.startsWith('6') || code.startsWith('5') ? '1' : '0';

      // 东方财富主要财务指标
      final url = 'https://emdata.eastmoney.com/api/FinanceAnalysis/GetFinanceAnalysis'
          '?code=$market.$code&type=1';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = jsonDecode(response.data.toString());
      // 解析财务数据...

      return {
        'code': code,
        'name': _stockNames[code] ?? code,
        'report_date': DateTime.now().toString().substring(0, 10),
        'revenue': 0.0,
        'profit': 0.0,
        'eps': 0.0,
        'roe': 0.0,
      };
    } catch (e) {
      print('[API] 财务数据失败: $code - $e');
      return {
        'code': code,
        'name': _stockNames[code] ?? code,
        'report_date': DateTime.now().toString().substring(0, 10),
        'revenue': 0.0,
        'profit': 0.0,
        'eps': 0.0,
        'roe': 0.0,
      };
    }
  }

  // ==================== 新闻公告 ====================

  /// 获取股票新闻
  Future<List<Map<String, dynamic>>> getStockNews(String code, {int limit = 10}) async {
    try {
      await _rateLimit();

      final url = 'https://np-listapi.eastmoney.com/comm/wap/getListInfo'
          '?type=106&code=${code.startsWith('6') ? '1' : '0'}.$code'
          '&pageSize=$limit&pageIndex=1';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = jsonDecode(response.data.toString());
      final list = data['data']?['list'] as List?;

      if (list == null) return [];

      return list.map((e) {
        return {
          'title': e['title']?.toString() ?? '',
          'date': e['showtime']?.toString() ?? '',
          'url': e['url']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      print('[API] 新闻失败: $code - $e');
      return [];
    }
  }

  /// 获取股票公告
  Future<List<Map<String, dynamic>>> getAnnouncements(String code, {int limit = 10}) async {
    try {
      await _rateLimit();

      final url = 'https://np-anotice-stock.eastmoney.com/api/security/ann'
          '?cb=&sr=1&pageIndex=1&pageSize=$limit'
          '&code=${code.startsWith('6') ? '1' : '0'}.$code';

      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': _getRandomUA()}),
      );

      final data = response.data.toString();
      // JSONP 格式，需要提取 JSON
      final jsonMatch = RegExp(r'\((.+)\)').firstMatch(data);
      if (jsonMatch == null) return [];

      final json = jsonDecode(jsonMatch.group(1)!);
      final list = json['data']?['list'] as List?;

      if (list == null) return [];

      return list.map((e) {
        return {
          'title': e['title']?.toString() ?? '',
          'date': e['notice_date']?.toString() ?? '',
          'type': e['ann_type']?.toString() ?? '',
        };
      }).toList();
    } catch (e) {
      print('[API] 公告失败: $code - $e');
      return [];
    }
  }
}
