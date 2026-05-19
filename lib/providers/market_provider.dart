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
        final code = e['code']?.toString() ?? '';
        final name = e['name']?.toString() ?? '未知';
        final market = e['market']?.toString() ?? (code.startsWith('6') ? 'sh' : 'sz');
        // API返回的是price，但Stock.fromQuote期望currentPrice
        final price = (e['price'] as num?)?.toDouble() ?? 0.0;
        final changePercent = (e['changePercent'] as num?)?.toDouble() ?? 0.0;
        
        print('[MarketProvider] 股票: $code $name 价格: $price 涨跌: $changePercent%');
        
        // 使用完整字段构建Stock
        return Stock(
          code: code,
          name: name,
          market: market,
          currentPrice: price,
          changePercent: changePercent,
          previousClose: price != 0 && changePercent != 0 ? price / (1 + changePercent/100) : 0,
          volume: (e['volume'] as num?)?.toInt() ?? 0,
          highPrice: (e['high'] as num?)?.toDouble() ?? 0.0,
          lowPrice: (e['low'] as num?)?.toDouble() ?? 0.0,
          openPrice: (e['open'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList().cast<Stock>();

      notifyListeners();
    } catch (e) {
      print('[MarketProvider] 获取热门股票失败: $e');
      _error = '获取热门股票失败: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
