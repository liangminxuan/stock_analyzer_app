import 'package:dio/dio.dart';
import 'backend_service.dart';

/// 智能选股服务 - 股票筛选和推荐
class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  final BackendService _backendService = BackendService();

  Dio get _dio => _backendService.dio;

  /// 检查股票数据是否已加载，如果未加载则等待
  /// 返回 true 表示数据已就绪，false 表示加载失败
  Future<bool> waitForStockData({Duration timeout = const Duration(minutes: 3)}) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final response = await _dio.get('/api/stock/data_status');
        final data = response.data;

        if (data['loaded'] == true) {
          print('[DiscoveryService] 股票数据已就绪, ${data['row_count']} 行');
          return true;
        }

        if (data['loading'] == true) {
          final elapsed = data['loading_elapsed'] ?? 0;
          print('[DiscoveryService] 数据加载中... 已耗时 ${elapsed}s');
          // 等待3秒后重试
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        // 既不在加载也没有数据，且有错误
        if (data['load_error'] != null) {
          print('[DiscoveryService] 数据加载失败: ${data['load_error']}');
          return false;
        }

        // 未知状态，等待后重试
        await Future.delayed(const Duration(seconds: 3));
      } catch (e) {
        print('[DiscoveryService] 检查数据状态失败: $e');
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    print('[DiscoveryService] 等待数据超时');
    return false;
  }

  /// 获取数据加载状态
  Future<Map<String, dynamic>> getStockDataStatus() async {
    try {
      final response = await _dio.get('/api/stock/data_status');
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      return {'loaded': false, 'loading': false, 'error': e.toString()};
    }
  }

  /// 股票筛选 - 根据条件筛选股票
  Future<Map<String, dynamic>> screenStocks({
    double? peMin,
    double? peMax,
    double? pbMin,
    double? pbMax,
    double? roeMin,
    double? marketCapMin,
    double? marketCapMax,
    double? turnoverMin,
    String? industry,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page.toString(),
        'size': size.toString(),
      };

      if (peMin != null) params['pe_min'] = peMin.toString();
      if (peMax != null) params['pe_max'] = peMax.toString();
      if (pbMin != null) params['pb_min'] = pbMin.toString();
      if (pbMax != null) params['pb_max'] = pbMax.toString();
      if (roeMin != null) params['roe_min'] = roeMin.toString();
      if (marketCapMin != null) params['market_cap_min'] = marketCapMin.toString();
      if (marketCapMax != null) params['market_cap_max'] = marketCapMax.toString();
      if (turnoverMin != null) params['turnover_min'] = turnoverMin.toString();
      if (industry != null && industry.isNotEmpty) params['industry'] = industry;

      final response = await _dio.get('/api/stock/screen', queryParameters: params);
      final data = response.data;

      if (data['success'] == true) {
        return {
          'success': true,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? 1,
          'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
          'filters': data['filters'] ?? {},
        };
      }
      return {'success': false, 'data': [], 'total': 0};
    } catch (e) {
      print('[DiscoveryService] 筛选股票失败: $e');
      return {'success': false, 'data': [], 'total': 0, 'error': e.toString()};
    }
  }

  /// 智能推荐 - 基于策略推荐股票
  Future<Map<String, dynamic>> recommendStocks({
    String strategy = 'comprehensive',
    int count = 10,
  }) async {
    try {
      final response = await _dio.get('/api/stock/recommend', queryParameters: {
        'strategy': strategy,
        'count': count.toString(),
      });
      final data = response.data;

      if (data['success'] == true) {
        return {
          'success': true,
          'strategy': data['strategy'] ?? strategy,
          'strategyName': data['strategy_name'] ?? '综合选股',
          'strategyDesc': data['strategy_desc'] ?? '',
          'count': data['count'] ?? 0,
          'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
        };
      }
      return {'success': false, 'data': [], 'count': 0};
    } catch (e) {
      print('[DiscoveryService] 推荐股票失败: $e');
      return {'success': false, 'data': [], 'count': 0, 'error': e.toString()};
    }
  }

  /// 获取行业列表
  Future<List<Map<String, dynamic>>> getIndustries() async {
    try {
      final response = await _dio.get('/api/stock/industries');
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      print('[DiscoveryService] 获取行业列表失败: $e');
      return [];
    }
  }
}
