import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/kline.dart';
import '../services/api_service.dart';

/// 股票Provider
class StockProvider extends ChangeNotifier {
  final StockApiService _apiService = StockApiService();

  Stock? _currentStock;
  Stock? get currentStock => _currentStock;

  List<KLineData> _klineData = [];
  List<KLineData> get klineData => _klineData;

  KLineAnalysis? _klineAnalysis;
  KLineAnalysis? get klineAnalysis => _klineAnalysis;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String _currentPeriod = 'day';
  String get currentPeriod => _currentPeriod;

  /// 获取股票详情
  Future<void> fetchStockDetail(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('[StockProvider] 获取详情: $code');
      final data = await _apiService.getStockQuote(code);
      print('[StockProvider] 返回: name=${data['name']} price=${data['currentPrice']} cp=${data['changePercent']}');

      // 始终用 Stock.fromQuote 构建，不做过严验证
      _currentStock = Stock.fromQuote(data);
      print('[StockProvider] 成功: ${_currentStock?.name} ${_currentStock?.currentPrice}');
    } catch (e) {
      _error = '加载失败: $e';
      print('[StockProvider] 详情失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取K线数据
  Future<void> fetchKLineData({
    required String code,
    String period = 'day',
    int limit = 100,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('[StockProvider] K线: code=$code period=$period');
      final data = await _apiService.getKLineData(
        code: code,
        period: period,
        count: limit,
      );
      print('[StockProvider] K线返回 ${data.length} 条');

      var klines = data.map((e) {
        return KLineData(
          time: DateTime.tryParse(e['time'] ?? '') ?? DateTime.now(),
          open: (e['open'] ?? 0).toDouble(),
          close: (e['close'] ?? 0).toDouble(),
          high: (e['high'] ?? 0).toDouble(),
          low: (e['low'] ?? 0).toDouble(),
          volume: (e['volume'] ?? 0).toInt(),
        );
      }).toList();

      klines = _calculateMA(klines);

      _klineData = klines;
      _currentPeriod = period;
      print('[StockProvider] K线处理完成，${klines.length} 条');
    } catch (e) {
      print('[StockProvider] K线失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 计算均线
  List<KLineData> _calculateMA(List<KLineData> data) {
    if (data.length < 5) return data;

    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final kline = entry.value;

      double? ma5, ma10, ma20;

      if (index >= 4) {
        final sum = data.sublist(index - 4, index + 1)
            .map((k) => k.close)
            .reduce((a, b) => a + b);
        ma5 = sum / 5;
      }

      if (index >= 9) {
        final sum = data.sublist(index - 9, index + 1)
            .map((k) => k.close)
            .reduce((a, b) => a + b);
        ma10 = sum / 10;
      }

      if (index >= 19) {
        final sum = data.sublist(index - 19, index + 1)
            .map((k) => k.close)
            .reduce((a, b) => a + b);
        ma20 = sum / 20;
      }

      return KLineData(
        time: kline.time,
        open: kline.open,
        close: kline.close,
        high: kline.high,
        low: kline.low,
        volume: kline.volume,
        ma5: ma5,
        ma10: ma10,
        ma20: ma20,
      );
    }).toList();
  }

  /// 切换K线周期 - 传纯代码
  Future<void> switchPeriod(String period) async {
    if (_currentStock == null) return;

    _currentPeriod = period;
    notifyListeners();

    await fetchKLineData(
      code: _currentStock!.code, // 传纯代码，API内部处理前缀
      period: period,
    );
  }

  /// 分析K线 - 传纯代码
  Future<void> analyzeKLine(String code, String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getKLineData(
        code: code, // API内部处理前缀
        period: 'day',
        count: 60,
      );

      if (data.isEmpty) {
        _klineAnalysis = null;
        return;
      }

      final klines = data.map((e) {
        return KLineData(
          time: DateTime.tryParse(e['time'] ?? '') ?? DateTime.now(),
          open: (e['open'] ?? 0).toDouble(),
          close: (e['close'] ?? 0).toDouble(),
          high: (e['high'] ?? 0).toDouble(),
          low: (e['low'] ?? 0).toDouble(),
          volume: (e['volume'] ?? 0).toInt(),
        );
      }).toList();

      _klineAnalysis = _generateAnalysis(klines, name);
    } catch (e) {
      print('[StockProvider] 分析失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 生成分析结果
  KLineAnalysis _generateAnalysis(List<KLineData> klines, String name) {
    if (klines.isEmpty) {
      return KLineAnalysis(
        trend: '未知',
        trendDescription: '数据不足，无法分析',
        technicalSummary: '',
        tradingAdvice: '',
        supportLevel: 0,
        resistanceLevel: 0,
        patterns: [],
        riskWarnings: ['数据不足'],
        confidenceScore: 0,
      );
    }

    final lastPrice = klines.last.close;
    final prices = klines.map((k) => k.close).toList();

    double calcMA(List<double> prices, int period) {
      if (prices.length < period) return 0;
      final slice = prices.sublist(prices.length - period);
      return slice.reduce((a, b) => a + b) / period;
    }

    final ma5 = calcMA(prices, 5);
    final ma10 = calcMA(prices, 10);
    final ma20 = calcMA(prices, 20);

    String trend = '震荡';
    if (ma5 > ma20 && lastPrice > ma5) {
      trend = '上涨趋势';
    } else if (ma5 < ma20 && lastPrice < ma5) {
      trend = '下跌趋势';
    }

    final lows = klines.map((k) => k.low).toList();
    final highs = klines.map((k) => k.high).toList();
    final support = lows.reduce((a, b) => a < b ? a : b);
    final resistance = highs.reduce((a, b) => a > b ? a : b);

    final firstPrice = prices.first;
    final change = lastPrice - firstPrice;
    final changePercent = firstPrice != 0 ? (change / firstPrice) * 100 : 0;

    return KLineAnalysis(
        trend: trend,
        trendDescription: '$name 当前处于 $trend，近60日涨跌 ${changePercent.toStringAsFixed(2)}%',
      technicalSummary: 'MA5=${ma5.toStringAsFixed(2)} | MA10=${ma10.toStringAsFixed(2)} | MA20=${ma20.toStringAsFixed(2)}',
      tradingAdvice: _generateAdvice(trend, ma5, ma10, lastPrice),
      supportLevel: support,
      resistanceLevel: resistance,
      patterns: _detectPatterns(klines),
      riskWarnings: _generateWarnings(klines),
      confidenceScore: 65,
    );
  }

  List<String> _detectPatterns(List<KLineData> klines) {
    final patterns = <String>[];
    if (klines.length < 5) return patterns;

    final recentHighs = klines.sublist(klines.length - 5).map((k) => k.high);
    if (klines.last.high >= recentHighs.reduce((a, b) => a > b ? a : b)) {
      patterns.add('近期创新高');
    }

    int upDays = 0;
    for (int i = klines.length - 1; i > 0 && klines[i].close > klines[i-1].close; i--) {
      upDays++;
    }
    if (upDays >= 3) {
      patterns.add('连续上涨$upDays天');
    }

    return patterns;
  }

  List<String> _generateWarnings(List<KLineData> klines) {
    final warnings = <String>[];
    if (klines.length >= 20) {
      final avgVolume = klines.sublist(0, klines.length - 1)
          .map((k) => k.volume)
          .reduce((a, b) => a + b) / (klines.length - 1);
      final lastVolume = klines.last.volume;
      if (lastVolume > avgVolume * 2) {
        warnings.add('成交量异常放大，请注意风险');
      }
    }
    return warnings;
  }

  String _generateAdvice(String trend, double ma5, double ma10, double price) {
    if (trend == '上涨趋势') {
      return '技术面显示上涨趋势，可考虑回调买入，注意设置止损位';
    } else if (trend == '下跌趋势') {
      return '技术面显示下跌趋势，建议观望或对冲风险';
    }
    return '目前处于震荡区间，建议高抛低吸，控制仓位';
  }

  /// 刷新数据 - 传纯代码
  Future<void> refresh() async {
    if (_currentStock == null) return;
    await fetchStockDetail(_currentStock!.code);
    await fetchKLineData(code: _currentStock!.code, period: _currentPeriod);
  }

  /// 清除数据
  void clear() {
    _currentStock = null;
    _klineData = [];
    _klineAnalysis = null;
    _error = null;
    _currentPeriod = 'day';
    notifyListeners();
  }
}
