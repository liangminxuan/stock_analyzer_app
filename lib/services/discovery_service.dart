import 'package:dio/dio.dart';
import 'backend_service.dart';

/// 智能选股服务 - 股票筛选和推荐
class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  final BackendService _backendService = BackendService();

  Dio get _dio => _backendService.dio;

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
