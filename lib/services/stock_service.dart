import '../models/stock.dart';
import '../models/kline.dart';
import 'api_service.dart';

/// 股票数据服务
class StockService {
  final StockApiService _apiService = StockApiService();

  /// 获取单只股票详情
  Future<Stock> getStockDetail(String code) async {
    try {
      // 确保代码格式正确
      final formattedCode = _formatCode(code);
      
      // 优先使用腾讯接口获取更详细的数据
      final data = await _apiService.getTencentRealTimeQuote(formattedCode);
      
      if (data.containsKey('error')) {
        // 如果腾讯接口失败，使用新浪接口
        final sinaData = await _apiService.getSinaRealTimeQuote(formattedCode);
        return Stock.fromSinaData(formattedCode, sinaData.toString());
      }
      
      return Stock.fromTencentData(formattedCode, data.toString());
    } catch (e) {
      throw Exception('获取股票详情失败: $e');
    }
  }

  /// 获取多只股票行情
  Future<List<Stock>> getBatchStocks(List<String> codes) async {
    try {
      final formattedCodes = codes.map(_formatCode).toList();
      final dataList = await _apiService.getSinaBatchQuotes(formattedCodes);
      
      return dataList.map((data) {
        final code = '${data['market']}${data['code']}';
        return Stock.fromSinaData(code, data.toString());
      }).toList();
    } catch (e) {
      throw Exception('获取批量股票失败: $e');
    }
  }

  /// 获取K线数据
  Future<List<KLineData>> getKLineData({
    required String code,
    required String period,
    int limit = 100,
  }) async {
    try {
      final formattedCode = _formatCode(code);
      final dataList = await _apiService.getKLineData(
        code: formattedCode,
        period: period,
        limit: limit,
      );
      
      return dataList.map((data) {
        return KLineData(
          time: DateTime.parse(data['time'].toString()),
          open: data['open'],
          high: data['high'],
          low: data['low'],
          close: data['close'],
          volume: data['volume'],
          amount: data['amount'],
        );
      }).toList();
    } catch (e) {
      throw Exception('获取K线数据失败: $e');
    }
  }

  /// 获取带技术指标的K线数据
  Future<List<KLineData>> getKLineWithIndicators({
    required String code,
    required String period,
    int limit = 100,
    List<String> indicators = const ['MA'],
  }) async {
    try {
      final klineData = await getKLineData(
        code: code,
        period: period,
        limit: limit + 60, // 多获取一些数据用于计算均线
      );
      
      if (klineData.isEmpty) return [];
      
      // 提取收盘价
      final closes = klineData.map((e) => e.close).toList();
      final highs = klineData.map((e) => e.high).toList();
      final lows = klineData.map((e) => e.low).toList();
      
      // 计算技术指标
      final ma5 = TechnicalIndicatorCalculator.calculateMA(closes, 5);
      final ma10 = TechnicalIndicatorCalculator.calculateMA(closes, 10);
      final ma20 = TechnicalIndicatorCalculator.calculateMA(closes, 20);
      final ma60 = TechnicalIndicatorCalculator.calculateMA(closes, 60);
      
      // 合并数据
      final result = <KLineData>[];
      for (int i = 0; i < klineData.length; i++) {
        result.add(klineData[i].copyWith(
          ma5: i < ma5.length ? ma5[i] : null,
          ma10: i < ma10.length ? ma10[i] : null,
          ma20: i < ma20.length ? ma20[i] : null,
          ma60: i < ma60.length ? ma60[i] : null,
        ));
      }
      
      // 返回去掉前面用于计算均线的数据
      return result.length > limit 
          ? result.sublist(result.length - limit) 
          : result;
    } catch (e) {
      throw Exception('获取K线数据失败: $e');
    }
  }

  /// 获取大盘指数
  Future<List<MarketIndex>> getMarketIndices() async {
    try {
      final dataList = await _apiService.getMarketIndices();
      
      return dataList.map((data) => MarketIndex(
        code: data['code'],
        name: data['name'],
        currentPoint: data['currentPoint'],
        change: data['change'],
        changePercent: data['changePercent'],
        volume: data['volume'].toInt(),
        turnover: data['turnover'],
      )).toList();
    } catch (e) {
      throw Exception('获取大盘指数失败: $e');
    }
  }

  /// 搜索股票
  Future<List<StockItem>> searchStocks(String keyword) async {
    try {
      if (keyword.isEmpty) return [];
      
      final results = await _apiService.searchStocks(keyword);
      
      return results.map((data) => StockItem(
        code: data['code'],
        name: data['name'],
        market: data['market'],
      )).toList();
    } catch (e) {
      throw Exception('搜索股票失败: $e');
    }
  }

  /// 获取股票列表
  Future<List<StockItem>> getStockList({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final results = await _apiService.getStockList(
        page: page,
        pageSize: pageSize,
      );
      
      return results.map((data) => StockItem(
        code: data['code'],
        name: data['name'],
        market: data['market'],
        price: data['price'],
        changePercent: data['changePercent'],
        volume: data['volume'],
      )).toList();
    } catch (e) {
      throw Exception('获取股票列表失败: $e');
    }
  }

  /// 格式化股票代码
  String _formatCode(String code) {
    // 如果已经包含市场前缀，直接返回
    if (code.startsWith('sh') || code.startsWith('sz') || code.startsWith('bj')) {
      return code;
    }
    
    // 根据代码规则判断市场
    if (code.startsWith('6')) {
      return 'sh$code';
    } else if (code.startsWith('0') || code.startsWith('3')) {
      return 'sz$code';
    } else if (code.startsWith('8') || code.startsWith('4')) {
      return 'bj$code';
    }
    
    // 默认返回上海市场
    return 'sh$code';
  }

  /// 计算技术指标
  TechnicalIndicators calculateIndicators(List<KLineData> klineData) {
    if (klineData.isEmpty) {
      return const TechnicalIndicators();
    }
    
    final closes = klineData.map((e) => e.close).toList();
    final highs = klineData.map((e) => e.high).toList();
    final lows = klineData.map((e) => e.low).toList();
    
    // 计算MA
    final ma5 = TechnicalIndicatorCalculator.calculateMA(closes, 5);
    final ma10 = TechnicalIndicatorCalculator.calculateMA(closes, 10);
    final ma20 = TechnicalIndicatorCalculator.calculateMA(closes, 20);
    final ma60 = TechnicalIndicatorCalculator.calculateMA(closes, 60);
    
    // 计算MACD
    final macd = TechnicalIndicatorCalculator.calculateMACD(closes);
    
    // 计算KDJ
    final kdj = TechnicalIndicatorCalculator.calculateKDJ(highs, lows, closes);
    
    // 计算RSI
    final rsi6 = TechnicalIndicatorCalculator.calculateRSI(closes, 6);
    final rsi12 = TechnicalIndicatorCalculator.calculateRSI(closes, 12);
    final rsi24 = TechnicalIndicatorCalculator.calculateRSI(closes, 24);
    
    // 计算BOLL
    final boll = TechnicalIndicatorCalculator.calculateBOLL(closes);
    
    return TechnicalIndicators(
      ma5: ma5,
      ma10: ma10,
      ma20: ma20,
      ma60: ma60,
      macdDif: macd['dif'] ?? [],
      macdDea: macd['dea'] ?? [],
      macdBar: macd['bar'] ?? [],
      kdjK: kdj['k'] ?? [],
      kdjD: kdj['d'] ?? [],
      kdjJ: kdj['j'] ?? [],
      rsi6: rsi6,
      rsi12: rsi12,
      rsi24: rsi24,
      bollUpper: boll['upper'] ?? [],
      bollMiddle: boll['middle'] ?? [],
      bollLower: boll['lower'] ?? [],
    );
  }

  /// 分析K线形态
  KLineAnalysis analyzeKLine(List<KLineData> data) {
    if (data.length < 20) {
      return const KLineAnalysis(
        trend: '数据不足',
        trendDescription: 'K线数据不足，无法进行分析',
        patterns: [],
        supportLevel: 0,
        resistanceLevel: 0,
        technicalSummary: '',
        tradingAdvice: '请提供更多数据',
        confidenceScore: 0,
        riskWarnings: [],
      );
    }
    
    // 趋势判断
    final trend = _determineTrend(data);
    
    // 形态识别
    final patterns = _identifyPatterns(data);
    
    // 支撑阻力位
    final support = _findSupportLevel(data);
    final resistance = _findResistanceLevel(data);
    
    // 技术指标总结
    final technicalSummary = _summarizeTechnicalIndicators(data);
    
    // 交易建议
    final advice = _generateTradingAdvice(data, trend, patterns);
    
    // 风险提示
    final risks = _identifyRisks(data);
    
    // 信心评分
    final confidence = _calculateConfidence(data, patterns);
    
    return KLineAnalysis(
      trend: trend['direction']!,
      trendDescription: trend['description']!,
      patterns: patterns,
      supportLevel: support,
      resistanceLevel: resistance,
      technicalSummary: technicalSummary,
      tradingAdvice: advice,
      confidenceScore: confidence,
      riskWarnings: risks,
    );
  }

  /// 判断趋势
  Map<String, String> _determineTrend(List<KLineData> data) {
    final recent = data.sublist(data.length - 20);
    final prices = recent.map((e) => e.close).toList();
    
    // 计算短期和长期均线
    final shortMA = prices.sublist(prices.length - 5).reduce((a, b) => a + b) / 5;
    final longMA = prices.reduce((a, b) => a + b) / prices.length;
    
    final currentPrice = prices.last;
    final priceChange = ((currentPrice - prices.first) / prices.first) * 100;
    
    if (shortMA > longMA * 1.02 && priceChange > 3) {
      return {
        'direction': '上升趋势',
        'description': '股价处于上升通道，短期均线在长期均线上方，近期涨幅${priceChange.toStringAsFixed(2)}%',
      };
    } else if (shortMA < longMA * 0.98 && priceChange < -3) {
      return {
        'direction': '下降趋势',
        'description': '股价处于下降通道，短期均线在长期均线下方，近期跌幅${priceChange.abs().toStringAsFixed(2)}%',
      };
    } else {
      return {
        'direction': '震荡整理',
        'description': '股价在区间内震荡，等待方向选择，近期波动${priceChange.abs().toStringAsFixed(2)}%',
      };
    }
  }

  /// 识别形态
  List<String> _identifyPatterns(List<KLineData> data) {
    final patterns = <String>[];
    final recent = data.sublist(data.length - 5);
    
    // 检查锤子线
    if (_isHammer(recent.last)) {
      patterns.add('锤子线');
    }
    
    // 检查吞没形态
    if (_isEngulfing(recent)) {
      patterns.add('吞没形态');
    }
    
    // 检查十字星
    if (_isDoji(recent.last)) {
      patterns.add('十字星');
    }
    
    // 检查连续涨跌
    final consecutiveUp = _countConsecutiveUp(recent);
    final consecutiveDown = _countConsecutiveDown(recent);
    
    if (consecutiveUp >= 3) {
      patterns.add('连续上涨$consecutiveUp天');
    } else if (consecutiveDown >= 3) {
      patterns.add('连续下跌$consecutiveDown天');
    }
    
    return patterns;
  }

  /// 检查锤子线
  bool _isHammer(KLineData data) {
    final bodySize = (data.close - data.open).abs();
    final lowerShadow = data.isUp ? data.open - data.low : data.close - data.low;
    final upperShadow = data.high - (data.isUp ? data.close : data.open);
    
    return lowerShadow > bodySize * 2 && upperShadow < bodySize;
  }

  /// 检查吞没形态
  bool _isEngulfing(List<KLineData> data) {
    if (data.length < 2) return false;
    
    final prev = data[data.length - 2];
    final curr = data.last;
    
    final prevBody = (prev.close - prev.open).abs();
    final currBody = (curr.close - curr.open).abs();
    
    return currBody > prevBody * 1.5 &&
           ((prev.isDown && curr.isUp) || (prev.isUp && curr.isDown));
  }

  /// 检查十字星
  bool _isDoji(KLineData data) {
    final bodySize = (data.close - data.open).abs();
    final totalRange = data.high - data.low;
    
    return bodySize < totalRange * 0.1;
  }

  /// 计算连续上涨天数
  int _countConsecutiveUp(List<KLineData> data) {
    int count = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i].isUp) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// 计算连续下跌天数
  int _countConsecutiveDown(List<KLineData> data) {
    int count = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i].isDown) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// 寻找支撑位
  double _findSupportLevel(List<KLineData> data) {
    final lows = data.map((e) => e.low).toList();
    lows.sort();
    return lows[lows.length ~/ 4]; // 取25%分位
  }

  /// 寻找阻力位
  double _findResistanceLevel(List<KLineData> data) {
    final highs = data.map((e) => e.high).toList();
    highs.sort();
    return highs[highs.length * 3 ~/ 4]; // 取75%分位
  }

  /// 技术指标总结
  String _summarizeTechnicalIndicators(List<KLineData> data) {
    final closes = data.map((e) => e.close).toList();
    final ma5 = TechnicalIndicatorCalculator.calculateMA(closes, 5);
    final ma10 = TechnicalIndicatorCalculator.calculateMA(closes, 10);
    final ma20 = TechnicalIndicatorCalculator.calculateMA(closes, 20);
    
    if (ma5.isEmpty || ma10.isEmpty || ma20.isEmpty) {
      return '技术指标数据不足';
    }
    
    final currentPrice = closes.last;
    final currentMA5 = ma5.last;
    final currentMA10 = ma10.last;
    final currentMA20 = ma20.last;
    
    final parts = <String>[];
    
    if (currentPrice > currentMA5 && currentMA5 > currentMA10) {
      parts.add('多头排列');
    } else if (currentPrice < currentMA5 && currentMA5 < currentMA10) {
      parts.add('空头排列');
    }
    
    if (currentPrice > currentMA20) {
      parts.add('价格在20日均线上方');
    } else {
      parts.add('价格在20日均线下方');
    }
    
    return parts.join('，');
  }

  /// 生成交易建议
  String _generateTradingAdvice(
    List<KLineData> data,
    Map<String, String> trend,
    List<String> patterns,
  ) {
    final recent = data.sublist(data.length - 5);
    final lastPrice = data.last.close;
    final avgVolume = data.map((e) => e.volume).reduce((a, b) => a + b) / data.length;
    final recentVolume = recent.map((e) => e.volume).reduce((a, b) => a + b) / recent.length;
    
    // 量价配合
    final volumeConfirm = recentVolume > avgVolume * 1.2;
    
    if (trend['direction'] == '上升趋势') {
      if (volumeConfirm) {
        return '建议持股或逢低买入，上升趋势确认，成交量配合良好';
      } else {
        return '建议观望，上升趋势但成交量不足，需警惕回调风险';
      }
    } else if (trend['direction'] == '下降趋势') {
      if (patterns.contains('锤子线') || patterns.contains('吞没形态')) {
        return '可能出现反弹信号，激进投资者可小仓位试探性买入，稳健投资者继续观望';
      }
      return '建议观望或减仓，下降趋势中，等待企稳信号';
    } else {
      return '建议观望，震荡行情中等待方向明确后再操作';
    }
  }

  /// 识别风险
  List<String> _identifyRisks(List<KLineData> data) {
    final risks = <String>[];
    final recent = data.sublist(data.length - 10);
    
    // 检查大幅波动
    final volatilities = recent.map((e) => (e.high - e.low) / e.open).toList();
    final avgVolatility = volatilities.reduce((a, b) => a + b) / volatilities.length;
    
    if (avgVolatility > 0.05) {
      risks.add('近期波动较大，注意控制风险');
    }
    
    // 检查成交量异常
    final volumes = data.map((e) => e.volume).toList();
    final avgVolume = volumes.reduce((a, b) => a + b) / volumes.length;
    final recentVolume = recent.map((e) => e.volume).reduce((a, b) => a + b) / recent.length;
    
    if (recentVolume > avgVolume * 2) {
      risks.add('成交量异常放大，可能有重大消息');
    } else if (recentVolume < avgVolume * 0.5) {
      risks.add('成交量萎缩，流动性风险');
    }
    
    return risks;
  }

  /// 计算信心评分
  int _calculateConfidence(List<KLineData> data, List<String> patterns) {
    int score = 50; // 基础分
    
    // 形态加分
    score += patterns.length * 5;
    
    // 数据量加分
    if (data.length >= 60) score += 10;
    else if (data.length >= 30) score += 5;
    
    // 趋势明确加分
    final trend = _determineTrend(data);
    if (trend['direction'] != '震荡整理') score += 10;
    
    return score.clamp(0, 100);
  }
}
