/// 股票基础信息模型
class Stock {
  final String code;                    // 股票代码
  final String name;                    // 股票名称
  final String market;                  // 市场 (sh/sz/bj)
  final double currentPrice;            // 当前价格
  final double previousClose;           // 昨收价
  final double openPrice;               // 开盘价
  final double highPrice;               // 最高价
  final double lowPrice;                // 最低价
  final double change;                  // 涨跌额
  final double changePercent;           // 涨跌幅 (%)
  final int volume;                     // 成交量（手）
  final double turnover;                // 成交额（万元）
  final List<double> bidPrices;         // 买1-5价格
  final List<int> bidVolumes;           // 买1-5数量
  final List<double> askPrices;         // 卖1-5价格
  final List<int> askVolumes;           // 卖1-5数量
  final DateTime? updateTime;           // 更新时间
  final String? industry;               // 所属行业
  final double marketCap;               // 总市值（亿元）
  final double peRatio;                 // 市盈率
  final double pbRatio;                 // 市净率

  const Stock({
    required this.code,
    required this.name,
    required this.market,
    this.currentPrice = 0.0,
    this.previousClose = 0.0,
    this.openPrice = 0.0,
    this.highPrice = 0.0,
    this.lowPrice = 0.0,
    this.change = 0.0,
    this.changePercent = 0.0,
    this.volume = 0,
    this.turnover = 0.0,
    this.bidPrices = const [],
    this.bidVolumes = const [],
    this.askPrices = const [],
    this.askVolumes = const [],
    this.updateTime,
    this.industry,
    this.marketCap = 0.0,
    this.peRatio = 0.0,
    this.pbRatio = 0.0,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      market: json['market'] as String? ?? '',
      currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0.0,
      previousClose: (json['previousClose'] as num?)?.toDouble() ?? 0.0,
      openPrice: (json['openPrice'] as num?)?.toDouble() ?? 0.0,
      highPrice: (json['highPrice'] as num?)?.toDouble() ?? 0.0,
      lowPrice: (json['lowPrice'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as int?) ?? 0,
      turnover: (json['turnover'] as num?)?.toDouble() ?? 0.0,
      bidPrices: (json['bidPrices'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      bidVolumes: (json['bidVolumes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      askPrices: (json['askPrices'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      askVolumes: (json['askVolumes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      industry: json['industry'] as String?,
      marketCap: (json['marketCap'] as num?)?.toDouble() ?? 0.0,
      peRatio: (json['peRatio'] as num?)?.toDouble() ?? 0.0,
      pbRatio: (json['pbRatio'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'market': market,
      'currentPrice': currentPrice,
      'previousClose': previousClose,
      'openPrice': openPrice,
      'highPrice': highPrice,
      'lowPrice': lowPrice,
      'change': change,
      'changePercent': changePercent,
      'volume': volume,
      'turnover': turnover,
      'bidPrices': bidPrices,
      'bidVolumes': bidVolumes,
      'askPrices': askPrices,
      'askVolumes': askVolumes,
      'updateTime': updateTime?.toIso8601String(),
      'industry': industry,
      'marketCap': marketCap,
      'peRatio': peRatio,
      'pbRatio': pbRatio,
    };
  }

  Stock copyWith({
    String? code,
    String? name,
    String? market,
    double? currentPrice,
    double? previousClose,
    double? openPrice,
    double? highPrice,
    double? lowPrice,
    double? change,
    double? changePercent,
    int? volume,
    double? turnover,
    List<double>? bidPrices,
    List<int>? bidVolumes,
    List<double>? askPrices,
    List<int>? askVolumes,
    DateTime? updateTime,
    String? industry,
    double? marketCap,
    double? peRatio,
    double? pbRatio,
  }) {
    return Stock(
      code: code ?? this.code,
      name: name ?? this.name,
      market: market ?? this.market,
      currentPrice: currentPrice ?? this.currentPrice,
      previousClose: previousClose ?? this.previousClose,
      openPrice: openPrice ?? this.openPrice,
      highPrice: highPrice ?? this.highPrice,
      lowPrice: lowPrice ?? this.lowPrice,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
      turnover: turnover ?? this.turnover,
      bidPrices: bidPrices ?? this.bidPrices,
      bidVolumes: bidVolumes ?? this.bidVolumes,
      askPrices: askPrices ?? this.askPrices,
      askVolumes: askVolumes ?? this.askVolumes,
      updateTime: updateTime ?? this.updateTime,
      industry: industry ?? this.industry,
      marketCap: marketCap ?? this.marketCap,
      peRatio: peRatio ?? this.peRatio,
      pbRatio: pbRatio ?? this.pbRatio,
    );
  }

  /// 获取完整代码（带市场前缀）
  String get fullCode => '$market$code';

  /// 判断涨跌状态
  bool get isUp => change > 0;
  bool get isDown => change < 0;
  bool get isFlat => change == 0;

  /// 获取涨跌幅颜色
  String get trendText {
    if (isUp) return '上涨';
    if (isDown) return '下跌';
    return '平盘';
  }

  /// 格式化涨跌幅显示
  String get changePercentText {
    final sign = isUp ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  /// 格式化涨跌额显示
  String get changeText {
    final sign = isUp ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}';
  }

  /// 格式化价格显示
  String get priceText => currentPrice.toStringAsFixed(2);

  /// 格式化成交量
  String get volumeText {
    if (volume >= 10000) {
      return '${(volume / 10000).toStringAsFixed(2)}万手';
    }
    return '$volume手';
  }

  /// 格式化成交额
  String get turnoverText {
    if (turnover >= 10000) {
      return '${(turnover / 10000).toStringAsFixed(2)}亿';
    }
    return '${turnover.toStringAsFixed(2)}万';
  }

  /// 格式化市值
  String get marketCapText {
    if (marketCap >= 10000) {
      return '${(marketCap / 10000).toStringAsFixed(2)}万亿';
    }
    return '${marketCap.toStringAsFixed(2)}亿';
  }

  /// 从API数据解析（通用方法）
  factory Stock.fromQuote(Map<String, dynamic> data) {
    final market = data['market'] as String? ?? 'sh';
    final code = data['code'] as String? ?? '';
    
    double currentPrice = 0.0;
    double previousClose = 0.0;
    double change = 0.0;
    double changePercent = 0.0;
    
    // 从 currentPrice 和 previousClose 计算涨跌
    if (data['currentPrice'] != null && data['previousClose'] != null) {
      currentPrice = (data['currentPrice'] as num).toDouble();
      previousClose = (data['previousClose'] as num).toDouble();
      change = currentPrice - previousClose;
      if (previousClose != 0) {
        changePercent = (change / previousClose) * 100;
      }
    } else if (data['change'] != null && data['changePercent'] != null) {
      change = (data['change'] as num).toDouble();
      changePercent = (data['changePercent'] as num).toDouble();
      if (data['currentPrice'] != null) {
        currentPrice = (data['currentPrice'] as num).toDouble();
        previousClose = currentPrice - change;
      }
    }

    return Stock(
      code: code,
      name: data['name'] as String? ?? '未知',
      market: market,
      currentPrice: currentPrice,
      previousClose: previousClose,
      openPrice: (data['open'] as num?)?.toDouble() ?? 0.0,
      highPrice: (data['high'] as num?)?.toDouble() ?? 0.0,
      lowPrice: (data['low'] as num?)?.toDouble() ?? 0.0,
      change: change,
      changePercent: changePercent,
      volume: (data['volume'] as num?)?.toInt() ?? 0,
      turnover: (data['turnover'] as num?)?.toDouble() ?? 0.0,
      marketCap: (data['marketCap'] as num?)?.toDouble() ?? 0.0,
      peRatio: (data['pe'] as num?)?.toDouble() ?? 0.0,
      bidPrices: (data['bidPrices'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble()).toList() ??
          [],
      bidVolumes: (data['bidVolumes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt()).toList() ??
          [],
      askPrices: (data['askPrices'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble()).toList() ??
          [],
      askVolumes: (data['askVolumes'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt()).toList() ??
          [],
    );
  }

  /// 从新浪API数据解析
  factory Stock.fromSinaData(String code, String data) {
    final parts = data.split(',');
    if (parts.length < 33) {
      return Stock(code: code, name: '未知', market: code.substring(0, 2));
    }

    final market = code.substring(0, 2);
    final stockCode = code.substring(2);

    return Stock(
      code: stockCode,
      name: parts[0],
      market: market,
      currentPrice: double.tryParse(parts[3]) ?? 0.0,
      previousClose: double.tryParse(parts[2]) ?? 0.0,
      openPrice: double.tryParse(parts[1]) ?? 0.0,
      highPrice: double.tryParse(parts[4]) ?? 0.0,
      lowPrice: double.tryParse(parts[5]) ?? 0.0,
      change: double.tryParse(parts[3]) != null &&
              double.tryParse(parts[2]) != null
          ? double.parse(parts[3]) - double.parse(parts[2])
          : 0.0,
      changePercent: double.tryParse(parts[2]) != null &&
              double.parse(parts[2]) != 0
          ? ((double.tryParse(parts[3]) ?? 0) - double.parse(parts[2])) /
              double.parse(parts[2]) *
              100
          : 0.0,
      volume: int.tryParse(parts[8]) ?? 0,
      turnover: (double.tryParse(parts[9]) ?? 0) / 10000,
      bidPrices: [
        double.tryParse(parts[11]) ?? 0,
        double.tryParse(parts[13]) ?? 0,
        double.tryParse(parts[15]) ?? 0,
        double.tryParse(parts[17]) ?? 0,
        double.tryParse(parts[19]) ?? 0,
      ],
      bidVolumes: [
        int.tryParse(parts[12]) ?? 0,
        int.tryParse(parts[14]) ?? 0,
        int.tryParse(parts[16]) ?? 0,
        int.tryParse(parts[18]) ?? 0,
        int.tryParse(parts[20]) ?? 0,
      ],
      askPrices: [
        double.tryParse(parts[21]) ?? 0,
        double.tryParse(parts[23]) ?? 0,
        double.tryParse(parts[25]) ?? 0,
        double.tryParse(parts[27]) ?? 0,
        double.tryParse(parts[29]) ?? 0,
      ],
      askVolumes: [
        int.tryParse(parts[22]) ?? 0,
        int.tryParse(parts[24]) ?? 0,
        int.tryParse(parts[26]) ?? 0,
        int.tryParse(parts[28]) ?? 0,
        int.tryParse(parts[30]) ?? 0,
      ],
      updateTime: DateTime.tryParse('${parts[30]} ${parts[31]}'),
    );
  }

  /// 从腾讯API数据解析
  factory Stock.fromTencentData(String code, String data) {
    final parts = data.split('~');
    if (parts.length < 45) {
      return Stock(code: code, name: '未知', market: code.substring(0, 2));
    }

    final market = code.substring(0, 2);
    final stockCode = code.substring(2);

    return Stock(
      code: stockCode,
      name: parts[1],
      market: market,
      currentPrice: double.tryParse(parts[3]) ?? 0.0,
      previousClose: double.tryParse(parts[4]) ?? 0.0,
      openPrice: double.tryParse(parts[5]) ?? 0.0,
      highPrice: double.tryParse(parts[33]) ?? 0.0,
      lowPrice: double.tryParse(parts[34]) ?? 0.0,
      change: double.tryParse(parts[31]) ?? 0.0,
      changePercent: double.tryParse(parts[32]) ?? 0.0,
      volume: (double.tryParse(parts[6]) ?? 0).toInt(),
      turnover: (double.tryParse(parts[37]) ?? 0) / 10000,
      marketCap: (double.tryParse(parts[44]) ?? 0) / 100000000,
      peRatio: double.tryParse(parts[39]) ?? 0.0,
      pbRatio: double.tryParse(parts[46]) ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Stock) return false;
    return code == other.code &&
        market == other.market &&
        currentPrice == other.currentPrice &&
        previousClose == other.previousClose &&
        change == other.change &&
        changePercent == other.changePercent &&
        volume == other.volume &&
        updateTime == other.updateTime;
  }

  @override
  int get hashCode => Object.hash(
        code,
        market,
        currentPrice,
        previousClose,
        change,
        changePercent,
        volume,
        updateTime,
      );

  @override
  String toString() {
    return 'Stock(code: $code, name: $name, market: $market, '
        'currentPrice: $currentPrice, change: $change, changePercent: $changePercent)';
  }
}

/// 股票列表项（简化版）
class StockItem {
  final String code;
  final String name;
  final String market;
  final double price;
  final double changePercent;
  final int volume;

  const StockItem({
    required this.code,
    required this.name,
    required this.market,
    this.price = 0.0,
    this.changePercent = 0.0,
    this.volume = 0,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      market: json['market'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'market': market,
      'price': price,
      'changePercent': changePercent,
      'volume': volume,
    };
  }

  StockItem copyWith({
    String? code,
    String? name,
    String? market,
    double? price,
    double? changePercent,
    int? volume,
  }) {
    return StockItem(
      code: code ?? this.code,
      name: name ?? this.name,
      market: market ?? this.market,
      price: price ?? this.price,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
    );
  }

  String get fullCode => '$market$code';
  bool get isUp => changePercent > 0;
  bool get isDown => changePercent < 0;

  String get changePercentText {
    final sign = isUp ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StockItem) return false;
    return code == other.code && market == other.market;
  }

  @override
  int get hashCode => Object.hash(code, market);

  @override
  String toString() {
    return 'StockItem(code: $code, name: $name, market: $market, '
        'price: $price, changePercent: $changePercent)';
  }
}

/// 大盘指数模型
class MarketIndex {
  final String code;
  final String name;
  final double currentPoint;
  final double change;
  final double changePercent;
  final int volume;
  final double turnover;

  const MarketIndex({
    required this.code,
    required this.name,
    this.currentPoint = 0.0,
    this.change = 0.0,
    this.changePercent = 0.0,
    this.volume = 0,
    this.turnover = 0.0,
  });

  factory MarketIndex.fromJson(Map<String, dynamic> json) {
    return MarketIndex(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      currentPoint: (json['currentPoint'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as int?) ?? 0,
      turnover: (json['turnover'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'currentPoint': currentPoint,
      'change': change,
      'changePercent': changePercent,
      'volume': volume,
      'turnover': turnover,
    };
  }

  MarketIndex copyWith({
    String? code,
    String? name,
    double? currentPoint,
    double? change,
    double? changePercent,
    int? volume,
    double? turnover,
  }) {
    return MarketIndex(
      code: code ?? this.code,
      name: name ?? this.name,
      currentPoint: currentPoint ?? this.currentPoint,
      change: change ?? this.change,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
      turnover: turnover ?? this.turnover,
    );
  }

  bool get isUp => change > 0;
  bool get isDown => change < 0;

  String get changePercentText {
    final sign = isUp ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  String get pointText => currentPoint.toStringAsFixed(2);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarketIndex) return false;
    return code == other.code && currentPoint == other.currentPoint;
  }

  @override
  int get hashCode => Object.hash(code, currentPoint);

  @override
  String toString() {
    return 'MarketIndex(code: $code, name: $name, currentPoint: $currentPoint, '
        'change: $change, changePercent: $changePercent)';
  }
}
