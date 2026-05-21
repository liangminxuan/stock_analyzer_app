import 'package:dio/dio.dart';

/// 后端服务客户端 - 连接 Python 后端获取公告、新闻、财报数据
class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  late Dio _dio;
  bool _initialized = false;

  /// 后端服务地址（已部署到 Render）
  static const String baseUrl = 'https://stock-analyzer-app-1-j7jd.onrender.com';

  Dio get dio {
    if (!_initialized) init();
    return _dio;
  }

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
    _initialized = true;
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final response = await dio.get('/health');
      return response.data['status'] == 'ok';
    } catch (e) {
      print('[BackendService] 健康检查失败: $e');
      return false;
    }
  }

  /// 获取公告列表
  Future<List<Map<String, dynamic>>> getAnnouncements({
    String? date,
    String? keyword,
    String type = '全部',
    int page = 1,
    int size = 20,
  }) async {
    try {
      final params = {
        'type': type,
        'page': page.toString(),
        'size': size.toString(),
      };
      if (date != null) params['date'] = date;
      if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

      final response = await dio.get('/api/announcements', queryParameters: params);
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('[BackendService] 获取公告失败: $e');
      return [];
    }
  }

  /// 获取个股新闻
  Future<List<Map<String, dynamic>>> getStockNews(String code) async {
    try {
      final response = await dio.get('/api/stock/news', queryParameters: {'code': code});
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('[BackendService] 获取个股新闻失败: $e');
      return [];
    }
  }

  /// 获取财务摘要
  Future<List<Map<String, dynamic>>> getStockFinancial(String code) async {
    try {
      final response = await dio.get('/api/stock/financial', queryParameters: {'code': code});
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('[BackendService] 获取财务摘要失败: $e');
      return [];
    }
  }

  /// 获取个股综合分析（公告+新闻+财报）
  Future<Map<String, dynamic>?> getStockAnalysis(String code, String name) async {
    try {
      final response = await dio.get('/api/stock/analysis', queryParameters: {
        'code': code,
        'name': name,
      });
      final data = response.data;

      if (data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      print('[BackendService] 获取综合分析失败: $e');
      return null;
    }
  }

  /// 获取今日公告（默认最新）
  Future<List<Map<String, dynamic>>> getTodayAnnouncements({String? keyword}) async {
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return getAnnouncements(date: date, keyword: keyword);
  }
}
