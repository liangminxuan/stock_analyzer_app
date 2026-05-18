import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/api_service.dart';

/// 市场行情Provider
class MarketProvider extends ChangeNotifier {
  final StockApiService _apiService = StockApiService();

  List<MarketIndex> _indices = [];
  List<MarketIndex> get indices => _indices;

  List<Stock> _hotStocks = [];
  List<Stock> get hotStocks => _hotStocks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// 获取大盘指数
  Future<void> fetchMarketIndices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getMarketIndices();
      print('[MarketProvider] 获取到 ${data.length} 条指数数据');

      _indices = data.map((e) {
        final point = (e['currentPoint'] ?? 0).toDouble();
        print('[MarketProvider] ${e['name']}: $point');

        return MarketIndex(
          code: e['code'] ?? '',
          name: e['name'] ?? '未知',
          currentPoint: point,
          change: (e['change'] ?? 0).toDouble(),
          changePercent: (e['changePercent'] ?? 0).toDouble(),
          volume: 0,
        );
      }).toList();
    } catch (e) {
      _error = '加载失败: $e';
      print('[MarketProvider] 获取指数失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取热门股票
  Future<void> fetchHotStocks() async {
    try {
      final data = await _apiService.getStockList(page: 1, pageSize: 20);
      print('[MarketProvider] 获取到 ${data.length} 条股票');

      _hotStocks = data.map((e) {
        return Stock.fromQuote({
          'code': e['code'] ?? '',
          'name': e['name'] ?? '未知',
          'market': e['market'] ?? 'sh',
          'currentPrice': (e['price'] ?? 0).toDouble(),
          'changePercent': (e['changePercent'] ?? 0).toDouble(),
          'volume': (e['volume'] ?? 0),
          'high': (e['high'] ?? 0).toDouble(),
          'low': (e['low'] ?? 0).toDouble(),
          'open': (e['open'] ?? 0).toDouble(),
        });
      }).toList().cast<Stock>();

      notifyListeners();
    } catch (e) {
      print('[MarketProvider] 获取热门股票失败: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
