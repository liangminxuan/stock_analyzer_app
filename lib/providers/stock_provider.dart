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

  /// 生成分析结果 - 白话化文案
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
        analysisProcess: '暂无足够数据进行分析。',
      );
    }

    final lastPrice = klines.last.close;
    final lastKline = klines.last;
    final prices = klines.map((k) => k.close).toList();
    final volumes = klines.map((k) => k.volume).toList();

    // 计算均线
    double calcMA(List<double> p, int period) {
      if (p.length < period) return 0;
      return p.sublist(p.length - period).reduce((a, b) => a + b) / period;
    }

    final ma5 = calcMA(prices, 5);
    final ma10 = calcMA(prices, 10);
    final ma20 = calcMA(prices, 20);

    // 判断趋势
    String trend;
    String trendReason;
    if (ma5 > ma20 && lastPrice > ma5) {
      trend = '上涨趋势';
      trendReason = '5日均线（${ma5.toStringAsFixed(2)}）在20日均线（${ma20.toStringAsFixed(2)}）上方，且当前价格（${lastPrice.toStringAsFixed(2)}）也在5日均线上方，说明短期走势偏强。';
    } else if (ma5 < ma20 && lastPrice < ma5) {
      trend = '下跌趋势';
      trendReason = '5日均线（${ma5.toStringAsFixed(2)}）在20日均线（${ma20.toStringAsFixed(2)}）下方，且当前价格（${lastPrice.toStringAsFixed(2)}）也在5日均线下方，说明短期走势偏弱。';
    } else if (ma5 > ma10 && ma10 > ma20) {
      trend = '多头排列';
      trendReason = '5日、10日、20日均线依次从上到下排列（均线多头排列），这是比较健康的上涨信号。';
    } else if (ma5 < ma10 && ma10 < ma20) {
      trend = '空头排列';
      trendReason = '5日、10日、20日均线依次从下到上排列（均线空头排列），说明市场整体偏弱。';
    } else {
      trend = '震荡整理';
      trendReason = '均线交织在一起，没有明确的方向，说明市场正在选择方向。';
    }

    // 支撑位和阻力位
    final support = klines.map((k) => k.low).reduce((a, b) => a < b ? a : b);
    final resistance = klines.map((k) => k.high).reduce((a, b) => a > b ? a : b);

    // 涨跌幅
    final firstPrice = prices.first;
    final changePercent = firstPrice != 0 ? ((lastPrice - firstPrice) / firstPrice) * 100 : 0.0;

    // 成交量分析
    final avgVolume = volumes.length > 1 ? volumes.sublist(0, volumes.length - 1).reduce((a, b) => a + b) / (volumes.length - 1) : 0;
    final lastVolume = lastKline.volume;
    final volumeRatio = avgVolume > 0 ? lastVolume / avgVolume : 1.0;
    String volumeDesc;
    if (volumeRatio > 2) {
      volumeDesc = '最近一天的成交量是近期平均的${volumeRatio.toStringAsFixed(1)}倍，明显放量，说明有大资金在操作。';
    } else if (volumeRatio > 1.3) {
      volumeDesc = '最近一天的成交量比近期平均水平略高（${volumeRatio.toStringAsFixed(1)}倍），属于温和放量。';
    } else if (volumeRatio < 0.5) {
      volumeDesc = '最近一天的成交量只有近期平均的${volumeRatio.toStringAsFixed(1)}倍，明显缩量，说明市场观望情绪浓厚。';
    } else {
      volumeDesc = '最近一天的成交量与近期平均水平基本持平（${volumeRatio.toStringAsFixed(1)}倍），属于正常水平。';
    }

    // 价格与均线关系
    String priceMaDesc;
    if (lastPrice > ma5 && lastPrice > ma10 && lastPrice > ma20) {
      priceMaDesc = '当前价格在所有均线上方，属于强势状态。';
    } else if (lastPrice < ma5 && lastPrice < ma10 && lastPrice < ma20) {
      priceMaDesc = '当前价格在所有均线下方，属于弱势状态。';
    } else {
      priceMaDesc = '当前价格在均线之间穿插，多空双方在争夺。';
    }

    // 构建分析过程
    final analysisProcess = [
      '第一步：看均线排列',
      'MA5（5日均线）= ${ma5.toStringAsFixed(2)}：代表最近5天的平均成交价，反映短期走势。',
      'MA10（10日均线）= ${ma10.toStringAsFixed(2)}：代表最近10天的平均成交价，反映中期走势。',
      'MA20（20日均线）= ${ma20.toStringAsFixed(2)}：代表最近20天的平均成交价，反映中长期走势。',
      '$trendReason',
      '',
      '第二步：看价格位置',
      '$priceMaDesc',
      '',
      '第三步：看成交量',
      volumeDesc,
      '',
      '第四步：看近期涨跌',
      '近${klines.length}个交易日，$name ${changePercent >= 0 ? "累计上涨" : "累计下跌"} ${changePercent.abs().toStringAsFixed(2)}%。',
      '近期最低点：${support.toStringAsFixed(2)}，最高点：${resistance.toStringAsFixed(2)}。',
    ].join('\n');

    // 技术指标白话解读
    final technicalSummary = [
      '【MA5 = ${ma5.toStringAsFixed(2)}】',
      lastPrice > ma5 ? '当前价格在MA5上方，短期趋势偏多。如果MA5向上拐头，说明短期可能继续上涨。' : '当前价格在MA5下方，短期趋势偏空。如果MA5向下拐头，说明短期可能继续下跌。',
      '',
      '【MA10 = ${ma10.toStringAsFixed(2)}】',
      lastPrice > ma10 ? '价格在MA10上方，中期走势尚可。MA10是很多散户关注的重要均线，守住MA10说明中期趋势没坏。' : '价格跌破MA10，中期走势转弱。很多投资者会在跌破MA10时减仓。',
      '',
      '【MA20 = ${ma20.toStringAsFixed(2)}】',
      lastPrice > ma20 ? '价格在MA20上方，中长期趋势仍然健康。MA20通常被视为"生命线"，站稳上方说明大趋势没变。' : '价格跌破MA20，需要警惕。MA20是重要的趋势分界线，跌破后可能进入调整期。',
    ].join('\n');

    // 形态识别
    final patterns = _detectPatterns(klines);

    // 风险提示
    final warnings = _generateWarnings(klines, volumeRatio);

    // 交易建议
    final tradingAdvice = _generateAdvice(trend, ma5, ma10, ma20, lastPrice, support, resistance, changePercent);

    // 趋势描述
    final trendDescription = '$name 目前处于【$trend】。\n\n'
        '近${klines.length}个交易日${changePercent >= 0 ? "累计上涨" : "累计下跌"} '
        '${changePercent.abs().toStringAsFixed(2)}%，'
        '当前价格 ${lastPrice.toStringAsFixed(2)} 元。';

    return KLineAnalysis(
      trend: trend,
      trendDescription: trendDescription,
      technicalSummary: technicalSummary,
      tradingAdvice: tradingAdvice,
      supportLevel: support,
      resistanceLevel: resistance,
      patterns: patterns,
      riskWarnings: warnings,
      confidenceScore: 65,
      analysisProcess: analysisProcess,
    );
  }

  List<String> _detectPatterns(List<KLineData> klines) {
    final patterns = <String>[];
    if (klines.length < 5) return patterns;

    // 检测近期新高
    final recentHighs = klines.sublist(klines.length - 5).map((k) => k.high);
    if (klines.last.high >= recentHighs.reduce((a, b) => a > b ? a : b)) {
      patterns.add('近期创出新高，说明买盘力量较强，但也要注意追高风险。');
    }

    // 检测近期新低
    final recentLows = klines.sublist(klines.length - 5).map((k) => k.low);
    if (klines.last.low <= recentLows.reduce((a, b) => a < b ? a : b)) {
      patterns.add('近期创出新低，说明卖盘压力较大，短期可能继续探底。');
    }

    // 连续上涨/下跌
    int upDays = 0;
    for (int i = klines.length - 1; i > 0 && klines[i].close > klines[i-1].close; i--) {
      upDays++;
    }
    if (upDays >= 3) {
      patterns.add('连续上涨${upDays}天，短期获利盘较多，注意回调风险。');
    }

    int downDays = 0;
    for (int i = klines.length - 1; i > 0 && klines[i].close < klines[i-1].close; i--) {
      downDays++;
    }
    if (downDays >= 3) {
      patterns.add('连续下跌${downDays}天，短期超跌，可能有技术性反弹。');
    }

    return patterns;
  }

  List<String> _generateWarnings(List<KLineData> klines, double volumeRatio) {
    final warnings = <String>[];
    if (volumeRatio > 2) {
      warnings.add('成交量异常放大（${volumeRatio.toStringAsFixed(1)}倍均量），可能是主力资金进出，需密切关注后续走势。');
    }
    if (klines.length >= 5) {
      final last5 = klines.sublist(klines.length - 5);
      final avgRange = last5.map((k) => k.high - k.low).reduce((a, b) => a + b) / 5;
      final lastRange = klines.last.high - klines.last.low;
      if (lastRange > avgRange * 2) {
        warnings.add('最近一天振幅明显放大，市场波动加剧，注意控制风险。');
      }
    }
    return warnings;
  }

  String _generateAdvice(String trend, double ma5, double ma10, double ma20, double price, double support, double resistance, double changePercent) {
    if (trend.contains('上涨') || trend.contains('多头')) {
      return '目前走势偏强，操作建议：\n\n'
          '1. 如果还没持仓，可以等价格回调到MA5（${ma5.toStringAsFixed(2)}）附近再考虑买入，不要追高。\n'
          '2. 如果已经持仓，可以继续持有，但要把止损位设在MA10（${ma10.toStringAsFixed(2)}）下方。\n'
          '3. 近期支撑位在 ${support.toStringAsFixed(2)}，阻力位在 ${resistance.toStringAsFixed(2)}。\n'
          '4. 如果放量突破阻力位，可以考虑加仓。';
    } else if (trend.contains('下跌') || trend.contains('空头')) {
      return '目前走势偏弱，操作建议：\n\n'
          '1. 如果还没持仓，建议继续观望，不要轻易抄底。\n'
          '2. 如果已经持仓，建议减仓或设置止损，止损位可以设在 ${support.toStringAsFixed(2)} 下方。\n'
          '3. 等待均线重新多头排列（MA5 > MA10 > MA20）再考虑入场。\n'
          '4. 如果价格跌破 ${support.toStringAsFixed(2)}，可能还会继续下跌，需要果断止损。';
    }
    return '目前市场方向不明，操作建议：\n\n'
        '1. 震荡行情适合高抛低吸，可以在支撑位 ${support.toStringAsFixed(2)} 附近买入，阻力位 ${resistance.toStringAsFixed(2)} 附近卖出。\n'
        '2. 控制仓位，不要满仓操作，保留资金应对方向选择。\n'
        '3. 关注成交量变化，如果放量突破阻力位，说明选择向上，可以追入。\n'
        '4. 如果放量跌破支撑位，说明选择向下，需要及时止损。';
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
