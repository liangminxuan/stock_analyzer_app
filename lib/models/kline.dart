/// K线数据模型
class KLineData {
  final DateTime time;           // 时间
  final double open;             // 开盘价
  final double high;             // 最高价
  final double low;              // 最低价
  final double close;            // 收盘价
  final int volume;              // 成交量
  final double amount;           // 成交额
  final double? ma5;             // 5日均线
  final double? ma10;            // 10日均线
  final double? ma20;            // 20日均线
  final double? ma60;            // 60日均线

  const KLineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.amount = 0.0,
    this.ma5 = 0.0,
    this.ma10 = 0.0,
    this.ma20 = 0.0,
    this.ma60 = 0.0,
  });

  factory KLineData.fromJson(Map<String, dynamic> json) {
    return KLineData(
      time: json['time'] != null
          ? DateTime.parse(json['time'] as String)
          : DateTime.now(),
      open: (json['open'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      close: (json['close'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as int?) ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      ma5: (json['ma5'] as num?)?.toDouble(),
      ma10: (json['ma10'] as num?)?.toDouble(),
      ma20: (json['ma20'] as num?)?.toDouble(),
      ma60: (json['ma60'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
      'amount': amount,
      'ma5': ma5,
      'ma10': ma10,
      'ma20': ma20,
      'ma60': ma60,
    };
  }

  KLineData copyWith({
    DateTime? time,
    double? open,
    double? high,
    double? low,
    double? close,
    int? volume,
    double? amount,
    double? ma5,
    double? ma10,
    double? ma20,
    double? ma60,
  }) {
    return KLineData(
      time: time ?? this.time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      amount: amount ?? this.amount,
      ma5: ma5 ?? this.ma5,
      ma10: ma10 ?? this.ma10,
      ma20: ma20 ?? this.ma20,
      ma60: ma60 ?? this.ma60,
    );
  }

  /// 是否上涨（收盘价高于开盘价）
  bool get isUp => close >= open;

  /// 是否下跌
  bool get isDown => close < open;

  /// 实体高度
  double get bodyHeight => (close - open).abs();

  /// 上影线高度
  double get upperShadow => high - (isUp ? close : open);

  /// 下影线高度
  double get lowerShadow => (isUp ? open : close) - low;

  /// 总振幅
  double get amplitude => high - low;

  /// 涨跌幅
  double get changePercent => open != 0 ? ((close - open) / open) * 100 : 0;

  /// 格式化时间
  String get formattedTime {
    return '${time.month}/${time.day}';
  }

  /// 从东方财富数据解析
  factory KLineData.fromEastMoneyData(List<dynamic> data) {
    // 东财数据格式: [时间, 开盘价, 收盘价, 最低价, 最高价, 成交量, 成交额, 振幅, 涨跌幅, 涨跌额, 换手率]
    final timestamp = data[0] is int
        ? data[0]
        : int.tryParse(data[0].toString()) ?? 0;

    return KLineData(
      time: DateTime.fromMillisecondsSinceEpoch(timestamp),
      open: (data[1] as num).toDouble(),
      close: (data[2] as num).toDouble(),
      low: (data[3] as num).toDouble(),
      high: (data[4] as num).toDouble(),
      volume: (data[5] as num).toInt(),
      amount: (data[6] as num).toDouble(),
    );
  }

  /// 从简化的数据解析
  factory KLineData.fromSimpleData({
    required DateTime time,
    required double open,
    required double high,
    required double low,
    required double close,
    required int volume,
    double? amount,
  }) {
    return KLineData(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      amount: amount ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KLineData) return false;
    return time == other.time && close == other.close && open == other.open;
  }

  @override
  int get hashCode => Object.hash(time, open, close);

  @override
  String toString() {
    return 'KLineData(time: $time, open: $open, high: $high, low: $low, close: $close, volume: $volume)';
  }
}

/// K线分析结果
class KLineAnalysis {
  final String trend;                    // 趋势判断
  final String trendDescription;         // 趋势描述
  final List<String> patterns;           // 识别的形态
  final double supportLevel;             // 支撑位
  final double resistanceLevel;          // 阻力位
  final String technicalSummary;         // 技术指标总结
  final String tradingAdvice;            // 交易建议
  final int confidenceScore;             // 信心评分 (0-100)
  final List<String> riskWarnings;       // 风险提示
  final String analysisProcess;          // 分析过程

  const KLineAnalysis({
    required this.trend,
    required this.trendDescription,
    required this.patterns,
    required this.supportLevel,
    required this.resistanceLevel,
    required this.technicalSummary,
    required this.tradingAdvice,
    required this.confidenceScore,
    required this.riskWarnings,
    this.analysisProcess = '',
  });

  factory KLineAnalysis.fromJson(Map<String, dynamic> json) {
    return KLineAnalysis(
      trend: json['trend'] as String? ?? '',
      trendDescription: json['trendDescription'] as String? ?? '',
      patterns: (json['patterns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      supportLevel: (json['supportLevel'] as num?)?.toDouble() ?? 0.0,
      resistanceLevel: (json['resistanceLevel'] as num?)?.toDouble() ?? 0.0,
      technicalSummary: json['technicalSummary'] as String? ?? '',
      tradingAdvice: json['tradingAdvice'] as String? ?? '',
      confidenceScore: (json['confidenceScore'] as int?) ?? 0,
      riskWarnings: (json['riskWarnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trend': trend,
      'trendDescription': trendDescription,
      'patterns': patterns,
      'supportLevel': supportLevel,
      'resistanceLevel': resistanceLevel,
      'technicalSummary': technicalSummary,
      'tradingAdvice': tradingAdvice,
      'confidenceScore': confidenceScore,
      'riskWarnings': riskWarnings,
    };
  }

  KLineAnalysis copyWith({
    String? trend,
    String? trendDescription,
    List<String>? patterns,
    double? supportLevel,
    double? resistanceLevel,
    String? technicalSummary,
    String? tradingAdvice,
    int? confidenceScore,
    List<String>? riskWarnings,
  }) {
    return KLineAnalysis(
      trend: trend ?? this.trend,
      trendDescription: trendDescription ?? this.trendDescription,
      patterns: patterns ?? this.patterns,
      supportLevel: supportLevel ?? this.supportLevel,
      resistanceLevel: resistanceLevel ?? this.resistanceLevel,
      technicalSummary: technicalSummary ?? this.technicalSummary,
      tradingAdvice: tradingAdvice ?? this.tradingAdvice,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      riskWarnings: riskWarnings ?? this.riskWarnings,
    );
  }

  /// 获取建议颜色
  String get adviceColor {
    if (tradingAdvice.contains('买入') || tradingAdvice.contains('强烈')) return 'red';
    if (tradingAdvice.contains('卖出')) return 'green';
    return 'gray';
  }

  /// 获取信心等级
  String get confidenceLevel {
    if (confidenceScore >= 80) return '高';
    if (confidenceScore >= 60) return '中';
    return '低';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KLineAnalysis) return false;
    return trend == other.trend &&
        tradingAdvice == other.tradingAdvice &&
        confidenceScore == other.confidenceScore;
  }

  @override
  int get hashCode => Object.hash(trend, tradingAdvice, confidenceScore);

  @override
  String toString() {
    return 'KLineAnalysis(trend: $trend, tradingAdvice: $tradingAdvice, confidenceScore: $confidenceScore)';
  }
}

/// 技术指标数据
class TechnicalIndicators {
  // MA均线
  final List<double> ma5;
  final List<double> ma10;
  final List<double> ma20;
  final List<double> ma60;

  // MACD
  final List<double> macdDif;
  final List<double> macdDea;
  final List<double> macdBar;

  // KDJ
  final List<double> kdjK;
  final List<double> kdjD;
  final List<double> kdjJ;

  // RSI
  final List<double> rsi6;
  final List<double> rsi12;
  final List<double> rsi24;

  // BOLL
  final List<double> bollUpper;
  final List<double> bollMiddle;
  final List<double> bollLower;

  const TechnicalIndicators({
    this.ma5 = const [],
    this.ma10 = const [],
    this.ma20 = const [],
    this.ma60 = const [],
    this.macdDif = const [],
    this.macdDea = const [],
    this.macdBar = const [],
    this.kdjK = const [],
    this.kdjD = const [],
    this.kdjJ = const [],
    this.rsi6 = const [],
    this.rsi12 = const [],
    this.rsi24 = const [],
    this.bollUpper = const [],
    this.bollMiddle = const [],
    this.bollLower = const [],
  });

  factory TechnicalIndicators.fromJson(Map<String, dynamic> json) {
    return TechnicalIndicators(
      ma5: (json['ma5'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      ma10: (json['ma10'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      ma20: (json['ma20'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      ma60: (json['ma60'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      macdDif: (json['macdDif'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      macdDea: (json['macdDea'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      macdBar: (json['macdBar'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      kdjK: (json['kdjK'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      kdjD: (json['kdjD'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      kdjJ: (json['kdjJ'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      rsi6: (json['rsi6'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      rsi12: (json['rsi12'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      rsi24: (json['rsi24'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      bollUpper: (json['bollUpper'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      bollMiddle: (json['bollMiddle'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      bollLower: (json['bollLower'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ma5': ma5,
      'ma10': ma10,
      'ma20': ma20,
      'ma60': ma60,
      'macdDif': macdDif,
      'macdDea': macdDea,
      'macdBar': macdBar,
      'kdjK': kdjK,
      'kdjD': kdjD,
      'kdjJ': kdjJ,
      'rsi6': rsi6,
      'rsi12': rsi12,
      'rsi24': rsi24,
      'bollUpper': bollUpper,
      'bollMiddle': bollMiddle,
      'bollLower': bollLower,
    };
  }

  TechnicalIndicators copyWith({
    List<double>? ma5,
    List<double>? ma10,
    List<double>? ma20,
    List<double>? ma60,
    List<double>? macdDif,
    List<double>? macdDea,
    List<double>? macdBar,
    List<double>? kdjK,
    List<double>? kdjD,
    List<double>? kdjJ,
    List<double>? rsi6,
    List<double>? rsi12,
    List<double>? rsi24,
    List<double>? bollUpper,
    List<double>? bollMiddle,
    List<double>? bollLower,
  }) {
    return TechnicalIndicators(
      ma5: ma5 ?? this.ma5,
      ma10: ma10 ?? this.ma10,
      ma20: ma20 ?? this.ma20,
      ma60: ma60 ?? this.ma60,
      macdDif: macdDif ?? this.macdDif,
      macdDea: macdDea ?? this.macdDea,
      macdBar: macdBar ?? this.macdBar,
      kdjK: kdjK ?? this.kdjK,
      kdjD: kdjD ?? this.kdjD,
      kdjJ: kdjJ ?? this.kdjJ,
      rsi6: rsi6 ?? this.rsi6,
      rsi12: rsi12 ?? this.rsi12,
      rsi24: rsi24 ?? this.rsi24,
      bollUpper: bollUpper ?? this.bollUpper,
      bollMiddle: bollMiddle ?? this.bollMiddle,
      bollLower: bollLower ?? this.bollLower,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TechnicalIndicators) return false;
    return _listEquals(ma5, other.ma5) &&
        _listEquals(ma10, other.ma10) &&
        _listEquals(ma20, other.ma20) &&
        _listEquals(ma60, other.ma60);
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(ma5.length, ma10.length, ma20.length, ma60.length);

  @override
  String toString() {
    return 'TechnicalIndicators(ma5: ${ma5.length}, ma10: ${ma10.length}, '
        'macdDif: ${macdDif.length}, kdjK: ${kdjK.length})';
  }
}

/// 技术指标计算工具类
class TechnicalIndicatorCalculator {

  /// 计算MA均线
  static List<double> calculateMA(List<double> prices, int period) {
    final result = <double>[];
    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        result.add(0);
        continue;
      }
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += prices[i - j];
      }
      result.add(sum / period);
    }
    return result;
  }

  /// 计算MACD
  static Map<String, List<double>> calculateMACD(
    List<double> prices, {
    int shortPeriod = 12,
    int longPeriod = 26,
    int signalPeriod = 9,
  }) {
    final ema12 = _calculateEMA(prices, shortPeriod);
    final ema26 = _calculateEMA(prices, longPeriod);

    final dif = <double>[];
    for (int i = 0; i < prices.length; i++) {
      dif.add(ema12[i] - ema26[i]);
    }

    final dea = _calculateEMA(dif, signalPeriod);

    final bar = <double>[];
    for (int i = 0; i < prices.length; i++) {
      bar.add((dif[i] - dea[i]) * 2);
    }

    return {
      'dif': dif,
      'dea': dea,
      'bar': bar,
    };
  }

  /// 计算KDJ
  static Map<String, List<double>> calculateKDJ(
    List<double> highs,
    List<double> lows,
    List<double> closes, {
    int period = 9,
  }) {
    final k = <double>[];
    final d = <double>[];
    final j = <double>[];

    double prevK = 50;
    double prevD = 50;

    for (int i = 0; i < closes.length; i++) {
      if (i < period - 1) {
        k.add(50);
        d.add(50);
        j.add(50);
        continue;
      }

      double highest = highs[i];
      double lowest = lows[i];
      for (int j = 1; j < period; j++) {
        if (highs[i - j] > highest) highest = highs[i - j];
        if (lows[i - j] < lowest) lowest = lows[i - j];
      }

      final rsv = highest != lowest
          ? ((closes[i] - lowest) / (highest - lowest)) * 100
          : 0;

      final currentK = (2 * prevK + rsv) / 3;
      final currentD = (2 * prevD + currentK) / 3;
      final currentJ = 3 * currentK - 2 * currentD;

      k.add(currentK);
      d.add(currentD);
      j.add(currentJ);

      prevK = currentK;
      prevD = currentD;
    }

    return {'k': k, 'd': d, 'j': j};
  }

  /// 计算RSI
  static List<double> calculateRSI(List<double> prices, int period) {
    final result = <double>[];
    double gainSum = 0;
    double lossSum = 0;

    for (int i = 1; i < prices.length; i++) {
      final change = prices[i] - prices[i - 1];
      if (change > 0) {
        gainSum += change;
      } else {
        lossSum += change.abs();
      }

      if (i < period) {
        result.add(50);
        continue;
      }

      final avgGain = gainSum / period;
      final avgLoss = lossSum / period;

      if (avgLoss == 0) {
        result.add(100);
      } else {
        final rs = avgGain / avgLoss;
        result.add(100 - (100 / (1 + rs)));
      }
    }

    // 补齐第一个元素
    result.insert(0, 50);
    return result;
  }

  /// 计算布林带
  static Map<String, List<double>> calculateBOLL(
    List<double> prices, {
    int period = 20,
    double stdDev = 2,
  }) {
    final middle = calculateMA(prices, period);
    final upper = <double>[];
    final lower = <double>[];

    for (int i = 0; i < prices.length; i++) {
      if (i < period - 1) {
        upper.add(0);
        lower.add(0);
        continue;
      }

      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += (prices[i - j] - middle[i]) * (prices[i - j] - middle[i]);
      }
      final std = (sum / period).sqrt();

      upper.add(middle[i] + stdDev * std);
      lower.add(middle[i] - stdDev * std);
    }

    return {'upper': upper, 'middle': middle, 'lower': lower};
  }

  /// 计算EMA
  static List<double> _calculateEMA(List<double> prices, int period) {
    final result = <double>[];
    final multiplier = 2 / (period + 1);

    for (int i = 0; i < prices.length; i++) {
      if (i == 0) {
        result.add(prices[i]);
      } else {
        result.add((prices[i] - result[i - 1]) * multiplier + result[i - 1]);
      }
    }

    return result;
  }
}

/// 扩展方法
extension DoubleExtension on double {
  double sqrt() {
    if (this <= 0) return 0;
    double x = this;
    double y = 1;
    while ((x - y).abs() > 0.000001) {
      x = (x + y) / 2;
      y = this / x;
    }
    return x;
  }
}
