import 'package:flutter/material.dart';
import '../services/backend_service.dart';

/// 公告Provider - 使用后端服务获取最新公告和新闻
class AnnouncementProvider extends ChangeNotifier {
  final BackendService _backendService = BackendService();

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> get announcements => _announcements;

  List<Map<String, dynamic>> _stockNews = [];
  List<Map<String, dynamic>> get stockNews => _stockNews;

  List<Map<String, dynamic>> _financialData = [];
  List<Map<String, dynamic>> get financialData => _financialData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// 获取今日公告
  Future<void> fetchTodayAnnouncements({String? keyword}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _backendService.getTodayAnnouncements(keyword: keyword);
      _announcements = results;
      print('[AnnouncementProvider] 获取到 ${results.length} 条公告');
    } catch (e) {
      _error = '获取公告失败: $e';
      print('[AnnouncementProvider] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取个股新闻
  Future<void> fetchStockNews(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _backendService.getStockNews(code);
      _stockNews = results;
      print('[AnnouncementProvider] 获取到 ${results.length} 条新闻');
    } catch (e) {
      _error = '获取新闻失败: $e';
      print('[AnnouncementProvider] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取财务数据
  Future<void> fetchFinancialData(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _backendService.getStockFinancial(code);
      _financialData = results;
      print('[AnnouncementProvider] 获取到 ${results.length} 期财务数据');
    } catch (e) {
      _error = '获取财务数据失败: $e';
      print('[AnnouncementProvider] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取个股综合分析
  Future<void> fetchStockAnalysis(String code, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 并行获取所有数据
      await Future.wait([
        _backendService.getStockNews(code).then((r) => _stockNews = r),
        _backendService.getStockFinancial(code).then((r) => _financialData = r),
        _backendService.getTodayAnnouncements(keyword: name).then((r) => _announcements = r),
      ]);
      print('[AnnouncementProvider] 综合分析获取完成');
    } catch (e) {
      _error = '获取分析数据失败: $e';
      print('[AnnouncementProvider] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _announcements = [];
    _stockNews = [];
    _financialData = [];
    _error = null;
    notifyListeners();
  }
}
