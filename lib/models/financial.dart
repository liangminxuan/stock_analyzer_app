/// 财务数据模型
class FinancialData {
  final String code;                      // 股票代码
  final String name;                      // 股票名称
  final String reportDate;                // 报告期
  final String reportType;                // 报告类型 (年报/季报)

  // 利润表数据
  final double revenue;                   // 营业收入
  final double revenueYoy;                // 营收同比增长率
  final double operatingProfit;           // 营业利润
  final double netProfit;                 // 净利润
  final double netProfitYoy;              // 净利润同比增长率
  final double grossProfit;               // 毛利润

  // 资产负债表数据
  final double totalAssets;               // 总资产
  final double totalLiabilities;          // 总负债
  final double equity;                    // 股东权益
  final double currentAssets;             // 流动资产
  final double currentLiabilities;        // 流动负债
  final double inventory;                 // 存货
  final double accountsReceivable;        // 应收账款

  // 现金流量表数据
  final double operatingCashFlow;         // 经营活动现金流
  final double investingCashFlow;         // 投资活动现金流
  final double financingCashFlow;         // 筹资活动现金流
  final double freeCashFlow;              // 自由现金流

  // 关键财务指标
  final double eps;                       // 每股收益
  final double epsYoy;                    // EPS同比增长
  final double bps;                       // 每股净资产
  final double roe;                       // 净资产收益率
  final double roa;                       // 总资产收益率
  final double grossMargin;               // 毛利率
  final double netMargin;                 // 净利率
  final double debtRatio;                 // 资产负债率
  final double currentRatio;              // 流动比率
  final double quickRatio;                // 速动比率
  final double assetTurnover;             // 总资产周转率
  final double inventoryTurnover;         // 存货周转率

  const FinancialData({
    required this.code,
    required this.name,
    required this.reportDate,
    required this.reportType,
    this.revenue = 0.0,
    this.revenueYoy = 0.0,
    this.operatingProfit = 0.0,
    this.netProfit = 0.0,
    this.netProfitYoy = 0.0,
    this.grossProfit = 0.0,
    this.totalAssets = 0.0,
    this.totalLiabilities = 0.0,
    this.equity = 0.0,
    this.currentAssets = 0.0,
    this.currentLiabilities = 0.0,
    this.inventory = 0.0,
    this.accountsReceivable = 0.0,
    this.operatingCashFlow = 0.0,
    this.investingCashFlow = 0.0,
    this.financingCashFlow = 0.0,
    this.freeCashFlow = 0.0,
    this.eps = 0.0,
    this.epsYoy = 0.0,
    this.bps = 0.0,
    this.roe = 0.0,
    this.roa = 0.0,
    this.grossMargin = 0.0,
    this.netMargin = 0.0,
    this.debtRatio = 0.0,
    this.currentRatio = 0.0,
    this.quickRatio = 0.0,
    this.assetTurnover = 0.0,
    this.inventoryTurnover = 0.0,
  });

  factory FinancialData.fromJson(Map<String, dynamic> json) {
    return FinancialData(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      reportDate: json['reportDate'] as String? ?? '',
      reportType: json['reportType'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      revenueYoy: (json['revenueYoy'] as num?)?.toDouble() ?? 0.0,
      operatingProfit: (json['operatingProfit'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
      netProfitYoy: (json['netProfitYoy'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0.0,
      totalAssets: (json['totalAssets'] as num?)?.toDouble() ?? 0.0,
      totalLiabilities: (json['totalLiabilities'] as num?)?.toDouble() ?? 0.0,
      equity: (json['equity'] as num?)?.toDouble() ?? 0.0,
      currentAssets: (json['currentAssets'] as num?)?.toDouble() ?? 0.0,
      currentLiabilities: (json['currentLiabilities'] as num?)?.toDouble() ?? 0.0,
      inventory: (json['inventory'] as num?)?.toDouble() ?? 0.0,
      accountsReceivable: (json['accountsReceivable'] as num?)?.toDouble() ?? 0.0,
      operatingCashFlow: (json['operatingCashFlow'] as num?)?.toDouble() ?? 0.0,
      investingCashFlow: (json['investingCashFlow'] as num?)?.toDouble() ?? 0.0,
      financingCashFlow: (json['financingCashFlow'] as num?)?.toDouble() ?? 0.0,
      freeCashFlow: (json['freeCashFlow'] as num?)?.toDouble() ?? 0.0,
      eps: (json['eps'] as num?)?.toDouble() ?? 0.0,
      epsYoy: (json['epsYoy'] as num?)?.toDouble() ?? 0.0,
      bps: (json['bps'] as num?)?.toDouble() ?? 0.0,
      roe: (json['roe'] as num?)?.toDouble() ?? 0.0,
      roa: (json['roa'] as num?)?.toDouble() ?? 0.0,
      grossMargin: (json['grossMargin'] as num?)?.toDouble() ?? 0.0,
      netMargin: (json['netMargin'] as num?)?.toDouble() ?? 0.0,
      debtRatio: (json['debtRatio'] as num?)?.toDouble() ?? 0.0,
      currentRatio: (json['currentRatio'] as num?)?.toDouble() ?? 0.0,
      quickRatio: (json['quickRatio'] as num?)?.toDouble() ?? 0.0,
      assetTurnover: (json['assetTurnover'] as num?)?.toDouble() ?? 0.0,
      inventoryTurnover: (json['inventoryTurnover'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'reportDate': reportDate,
      'reportType': reportType,
      'revenue': revenue,
      'revenueYoy': revenueYoy,
      'operatingProfit': operatingProfit,
      'netProfit': netProfit,
      'netProfitYoy': netProfitYoy,
      'grossProfit': grossProfit,
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'equity': equity,
      'currentAssets': currentAssets,
      'currentLiabilities': currentLiabilities,
      'inventory': inventory,
      'accountsReceivable': accountsReceivable,
      'operatingCashFlow': operatingCashFlow,
      'investingCashFlow': investingCashFlow,
      'financingCashFlow': financingCashFlow,
      'freeCashFlow': freeCashFlow,
      'eps': eps,
      'epsYoy': epsYoy,
      'bps': bps,
      'roe': roe,
      'roa': roa,
      'grossMargin': grossMargin,
      'netMargin': netMargin,
      'debtRatio': debtRatio,
      'currentRatio': currentRatio,
      'quickRatio': quickRatio,
      'assetTurnover': assetTurnover,
      'inventoryTurnover': inventoryTurnover,
    };
  }

  FinancialData copyWith({
    String? code,
    String? name,
    String? reportDate,
    String? reportType,
    double? revenue,
    double? revenueYoy,
    double? operatingProfit,
    double? netProfit,
    double? netProfitYoy,
    double? grossProfit,
    double? totalAssets,
    double? totalLiabilities,
    double? equity,
    double? currentAssets,
    double? currentLiabilities,
    double? inventory,
    double? accountsReceivable,
    double? operatingCashFlow,
    double? investingCashFlow,
    double? financingCashFlow,
    double? freeCashFlow,
    double? eps,
    double? epsYoy,
    double? bps,
    double? roe,
    double? roa,
    double? grossMargin,
    double? netMargin,
    double? debtRatio,
    double? currentRatio,
    double? quickRatio,
    double? assetTurnover,
    double? inventoryTurnover,
  }) {
    return FinancialData(
      code: code ?? this.code,
      name: name ?? this.name,
      reportDate: reportDate ?? this.reportDate,
      reportType: reportType ?? this.reportType,
      revenue: revenue ?? this.revenue,
      revenueYoy: revenueYoy ?? this.revenueYoy,
      operatingProfit: operatingProfit ?? this.operatingProfit,
      netProfit: netProfit ?? this.netProfit,
      netProfitYoy: netProfitYoy ?? this.netProfitYoy,
      grossProfit: grossProfit ?? this.grossProfit,
      totalAssets: totalAssets ?? this.totalAssets,
      totalLiabilities: totalLiabilities ?? this.totalLiabilities,
      equity: equity ?? this.equity,
      currentAssets: currentAssets ?? this.currentAssets,
      currentLiabilities: currentLiabilities ?? this.currentLiabilities,
      inventory: inventory ?? this.inventory,
      accountsReceivable: accountsReceivable ?? this.accountsReceivable,
      operatingCashFlow: operatingCashFlow ?? this.operatingCashFlow,
      investingCashFlow: investingCashFlow ?? this.investingCashFlow,
      financingCashFlow: financingCashFlow ?? this.financingCashFlow,
      freeCashFlow: freeCashFlow ?? this.freeCashFlow,
      eps: eps ?? this.eps,
      epsYoy: epsYoy ?? this.epsYoy,
      bps: bps ?? this.bps,
      roe: roe ?? this.roe,
      roa: roa ?? this.roa,
      grossMargin: grossMargin ?? this.grossMargin,
      netMargin: netMargin ?? this.netMargin,
      debtRatio: debtRatio ?? this.debtRatio,
      currentRatio: currentRatio ?? this.currentRatio,
      quickRatio: quickRatio ?? this.quickRatio,
      assetTurnover: assetTurnover ?? this.assetTurnover,
      inventoryTurnover: inventoryTurnover ?? this.inventoryTurnover,
    );
  }

  // 计算属性

  /// 营业利润率
  double get operatingMargin => revenue != 0 ? (operatingProfit / revenue) * 100 : 0;

  /// 权益乘数
  double get equityMultiplier => equity != 0 ? totalAssets / equity : 0;

  /// 杜邦分析ROE
  double get dupontRoe => netMargin * assetTurnover * equityMultiplier;

  /// 现金流覆盖率
  double get cashFlowCoverage => netProfit != 0 ? operatingCashFlow / netProfit : 0;

  /// 格式化金额（亿元）
  String formatAmount(double amount) {
    if (amount.abs() >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(2)}亿';
    } else if (amount.abs() >= 10000) {
      return '${(amount / 10000).toStringAsFixed(2)}万';
    }
    return amount.toStringAsFixed(2);
  }

  /// 格式化百分比
  String formatPercent(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}%';
  }

  /// 获取财务健康度评分 (0-100)
  int get healthScore {
    int score = 50; // 基础分

    // 盈利能力 (25分)
    if (roe > 15) score += 10;
    else if (roe > 10) score += 5;
    else if (roe > 5) score += 2;

    if (netMargin > 20) score += 10;
    else if (netMargin > 10) score += 5;
    else if (netMargin > 5) score += 2;

    if (grossMargin > 30) score += 5;
    else if (grossMargin > 20) score += 2;

    // 成长性 (20分)
    if (revenueYoy > 20) score += 10;
    else if (revenueYoy > 10) score += 5;
    else if (revenueYoy > 0) score += 2;

    if (netProfitYoy > 20) score += 10;
    else if (netProfitYoy > 10) score += 5;
    else if (netProfitYoy > 0) score += 2;

    // 偿债能力 (15分)
    if (debtRatio < 40) score += 10;
    else if (debtRatio < 60) score += 5;

    if (currentRatio > 2) score += 5;
    else if (currentRatio > 1.5) score += 2;

    // 现金流 (10分)
    if (operatingCashFlow > 0) score += 5;
    if (freeCashFlow > 0) score += 5;

    return score.clamp(0, 100);
  }

  /// 获取健康等级
  String get healthLevel {
    final score = healthScore;
    if (score >= 80) return '优秀';
    if (score >= 60) return '良好';
    if (score >= 40) return '一般';
    return '较差';
  }

  /// 获取主要风险点
  List<String> get riskPoints {
    final risks = <String>[];

    if (debtRatio > 70) risks.add('资产负债率过高');
    if (currentRatio < 1) risks.add('短期偿债能力不足');
    if (revenueYoy < 0) risks.add('营收负增长');
    if (netProfitYoy < 0) risks.add('净利润负增长');
    if (operatingCashFlow < 0) risks.add('经营现金流为负');
    if (roe < 5) risks.add('盈利能力较弱');
    if (accountsReceivable > revenue * 0.5) risks.add('应收账款占比过高');

    return risks;
  }

  /// 获取亮点
  List<String> get highlights {
    final highlights = <String>[];

    if (roe > 15) highlights.add('ROE优秀');
    if (netMargin > 20) highlights.add('净利率较高');
    if (revenueYoy > 20) highlights.add('营收高增长');
    if (netProfitYoy > 20) highlights.add('净利润高增长');
    if (debtRatio < 40) highlights.add('财务杠杆低');
    if (freeCashFlow > netProfit * 0.5) highlights.add('现金流充裕');

    return highlights;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FinancialData) return false;
    return code == other.code &&
        reportDate == other.reportDate &&
        reportType == other.reportType;
  }

  @override
  int get hashCode => Object.hash(code, reportDate, reportType);

  @override
  String toString() {
    return 'FinancialData(code: $code, name: $name, reportDate: $reportDate, '
        'reportType: $reportType, revenue: $revenue, netProfit: $netProfit)';
  }
}

/// 财务分析结果
class FinancialAnalysis {
  final String profitabilityAnalysis;      // 盈利能力分析
  final String growthAnalysis;             // 成长性分析
  final String solvencyAnalysis;           // 偿债能力分析
  final String efficiencyAnalysis;         // 运营效率分析
  final String cashFlowAnalysis;           // 现金流分析
  final int healthScore;                   // 健康度评分
  final String healthLevel;                // 健康等级
  final List<String> riskWarnings;         // 风险提示
  final List<String> investmentHighlights; // 投资亮点
  final String investmentAdvice;           // 投资建议
  final String summary;                    // 综合分析总结

  const FinancialAnalysis({
    required this.profitabilityAnalysis,
    required this.growthAnalysis,
    required this.solvencyAnalysis,
    required this.efficiencyAnalysis,
    required this.cashFlowAnalysis,
    required this.healthScore,
    required this.healthLevel,
    required this.riskWarnings,
    required this.investmentHighlights,
    required this.investmentAdvice,
    required this.summary,
  });

  factory FinancialAnalysis.fromJson(Map<String, dynamic> json) {
    return FinancialAnalysis(
      profitabilityAnalysis: json['profitabilityAnalysis'] as String? ?? '',
      growthAnalysis: json['growthAnalysis'] as String? ?? '',
      solvencyAnalysis: json['solvencyAnalysis'] as String? ?? '',
      efficiencyAnalysis: json['efficiencyAnalysis'] as String? ?? '',
      cashFlowAnalysis: json['cashFlowAnalysis'] as String? ?? '',
      healthScore: (json['healthScore'] as int?) ?? 0,
      healthLevel: json['healthLevel'] as String? ?? '',
      riskWarnings: (json['riskWarnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      investmentHighlights: (json['investmentHighlights'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      investmentAdvice: json['investmentAdvice'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profitabilityAnalysis': profitabilityAnalysis,
      'growthAnalysis': growthAnalysis,
      'solvencyAnalysis': solvencyAnalysis,
      'efficiencyAnalysis': efficiencyAnalysis,
      'cashFlowAnalysis': cashFlowAnalysis,
      'healthScore': healthScore,
      'healthLevel': healthLevel,
      'riskWarnings': riskWarnings,
      'investmentHighlights': investmentHighlights,
      'investmentAdvice': investmentAdvice,
      'summary': summary,
    };
  }

  FinancialAnalysis copyWith({
    String? profitabilityAnalysis,
    String? growthAnalysis,
    String? solvencyAnalysis,
    String? efficiencyAnalysis,
    String? cashFlowAnalysis,
    int? healthScore,
    String? healthLevel,
    List<String>? riskWarnings,
    List<String>? investmentHighlights,
    String? investmentAdvice,
    String? summary,
  }) {
    return FinancialAnalysis(
      profitabilityAnalysis: profitabilityAnalysis ?? this.profitabilityAnalysis,
      growthAnalysis: growthAnalysis ?? this.growthAnalysis,
      solvencyAnalysis: solvencyAnalysis ?? this.solvencyAnalysis,
      efficiencyAnalysis: efficiencyAnalysis ?? this.efficiencyAnalysis,
      cashFlowAnalysis: cashFlowAnalysis ?? this.cashFlowAnalysis,
      healthScore: healthScore ?? this.healthScore,
      healthLevel: healthLevel ?? this.healthLevel,
      riskWarnings: riskWarnings ?? this.riskWarnings,
      investmentHighlights: investmentHighlights ?? this.investmentHighlights,
      investmentAdvice: investmentAdvice ?? this.investmentAdvice,
      summary: summary ?? this.summary,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FinancialAnalysis) return false;
    return healthScore == other.healthScore &&
        investmentAdvice == other.investmentAdvice;
  }

  @override
  int get hashCode => Object.hash(healthScore, investmentAdvice);

  @override
  String toString() {
    return 'FinancialAnalysis(healthScore: $healthScore, healthLevel: $healthLevel, '
        'investmentAdvice: $investmentAdvice)';
  }
}

/// 财务数据对比
class FinancialComparison {
  final String code1;
  final String name1;
  final String code2;
  final String name2;
  final Map<String, ComparisonItem> comparisons;

  const FinancialComparison({
    required this.code1,
    required this.name1,
    required this.code2,
    required this.name2,
    required this.comparisons,
  });

  factory FinancialComparison.fromJson(Map<String, dynamic> json) {
    final comparisonsMap = <String, ComparisonItem>{};
    final rawComparisons = json['comparisons'] as Map<String, dynamic>?;
    if (rawComparisons != null) {
      rawComparisons.forEach((key, value) {
        comparisonsMap[key] = ComparisonItem.fromJson(value as Map<String, dynamic>);
      });
    }
    return FinancialComparison(
      code1: json['code1'] as String? ?? '',
      name1: json['name1'] as String? ?? '',
      code2: json['code2'] as String? ?? '',
      name2: json['name2'] as String? ?? '',
      comparisons: comparisonsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code1': code1,
      'name1': name1,
      'code2': code2,
      'name2': name2,
      'comparisons': comparisons.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  FinancialComparison copyWith({
    String? code1,
    String? name1,
    String? code2,
    String? name2,
    Map<String, ComparisonItem>? comparisons,
  }) {
    return FinancialComparison(
      code1: code1 ?? this.code1,
      name1: name1 ?? this.name1,
      code2: code2 ?? this.code2,
      name2: name2 ?? this.name2,
      comparisons: comparisons ?? this.comparisons,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FinancialComparison) return false;
    return code1 == other.code1 && code2 == other.code2;
  }

  @override
  int get hashCode => Object.hash(code1, code2);

  @override
  String toString() {
    return 'FinancialComparison(code1: $code1, name1: $name1, code2: $code2, name2: $name2)';
  }
}

/// 对比项
class ComparisonItem {
  final String indicator;      // 指标名称
  final double value1;         // 股票1的值
  final double value2;         // 股票2的值
  final String unit;           // 单位
  final bool higherIsBetter;   // 是否越高越好

  const ComparisonItem({
    required this.indicator,
    required this.value1,
    required this.value2,
    required this.unit,
    required this.higherIsBetter,
  });

  factory ComparisonItem.fromJson(Map<String, dynamic> json) {
    return ComparisonItem(
      indicator: json['indicator'] as String? ?? '',
      value1: (json['value1'] as num?)?.toDouble() ?? 0.0,
      value2: (json['value2'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      higherIsBetter: (json['higherIsBetter'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'indicator': indicator,
      'value1': value1,
      'value2': value2,
      'unit': unit,
      'higherIsBetter': higherIsBetter,
    };
  }

  ComparisonItem copyWith({
    String? indicator,
    double? value1,
    double? value2,
    String? unit,
    bool? higherIsBetter,
  }) {
    return ComparisonItem(
      indicator: indicator ?? this.indicator,
      value1: value1 ?? this.value1,
      value2: value2 ?? this.value2,
      unit: unit ?? this.unit,
      higherIsBetter: higherIsBetter ?? this.higherIsBetter,
    );
  }

  /// 计算差值
  double get difference => value1 - value2;

  /// 计算差异百分比
  double get differencePercent => value2 != 0 ? ((value1 - value2) / value2) * 100 : 0;

  /// 哪个更好
  int get betterStock {
    if (higherIsBetter) {
      return value1 > value2 ? 1 : (value1 < value2 ? 2 : 0);
    } else {
      return value1 < value2 ? 1 : (value1 > value2 ? 2 : 0);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComparisonItem) return false;
    return indicator == other.indicator && value1 == other.value1 && value2 == other.value2;
  }

  @override
  int get hashCode => Object.hash(indicator, value1, value2);

  @override
  String toString() {
    return 'ComparisonItem(indicator: $indicator, value1: $value1, value2: $value2)';
  }
}

/// 财报公告
class FinancialReport {
  final String code;
  final String name;
  final String title;
  final String reportDate;
  final String reportType;
  final String? content;
  final String? pdfUrl;
  final DateTime? publishTime;

  const FinancialReport({
    required this.code,
    required this.name,
    required this.title,
    required this.reportDate,
    required this.reportType,
    this.content,
    this.pdfUrl,
    this.publishTime,
  });

  factory FinancialReport.fromJson(Map<String, dynamic> json) {
    return FinancialReport(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      reportDate: json['reportDate'] as String? ?? '',
      reportType: json['reportType'] as String? ?? '',
      content: json['content'] as String?,
      pdfUrl: json['pdfUrl'] as String?,
      publishTime: json['publishTime'] != null
          ? DateTime.tryParse(json['publishTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'title': title,
      'reportDate': reportDate,
      'reportType': reportType,
      'content': content,
      'pdfUrl': pdfUrl,
      'publishTime': publishTime?.toIso8601String(),
    };
  }

  FinancialReport copyWith({
    String? code,
    String? name,
    String? title,
    String? reportDate,
    String? reportType,
    String? content,
    String? pdfUrl,
    DateTime? publishTime,
  }) {
    return FinancialReport(
      code: code ?? this.code,
      name: name ?? this.name,
      title: title ?? this.title,
      reportDate: reportDate ?? this.reportDate,
      reportType: reportType ?? this.reportType,
      content: content ?? this.content,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      publishTime: publishTime ?? this.publishTime,
    );
  }

  /// 获取报告类型中文
  String get reportTypeText {
    switch (reportType) {
      case 'annual':
        return '年报';
      case 'q1':
        return '一季报';
      case 'q2':
        return '半年报';
      case 'q3':
        return '三季报';
      default:
        return reportType;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FinancialReport) return false;
    return code == other.code && reportDate == other.reportDate && reportType == other.reportType;
  }

  @override
  int get hashCode => Object.hash(code, reportDate, reportType);

  @override
  String toString() {
    return 'FinancialReport(code: $code, name: $name, title: $title, reportDate: $reportDate, reportType: $reportType)';
  }
}
