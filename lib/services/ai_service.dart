import '../config/constants.dart';
import '../models/kline.dart';
import '../models/financial.dart';
import '../models/announcement.dart';

/// AI分析服务
class AIService {
  
  /// 分析K线数据
  Future<KLineAnalysis> analyzeKLine({
    required String code,
    required String name,
    required String period,
    required List<KLineData> data,
  }) async {
    try {
      // 构建K线数据文本
      final dataText = _buildKLineDataText(data);
      
      // 构建提示词
      final prompt = AppConstants.kLineAnalysisPrompt
          .replaceAll('{code}', code)
          .replaceAll('{name}', name)
          .replaceAll('{period}', period)
          .replaceAll('{data}', dataText);
      
      // 这里可以调用AI API进行真实分析
      // 目前使用模拟分析
      return _mockKLineAnalysis(data);
    } catch (e) {
      throw Exception('K线分析失败: $e');
    }
  }

  /// 分析财务数据
  Future<FinancialAnalysis> analyzeFinancial({
    required String code,
    required String name,
    required FinancialData data,
  }) async {
    try {
      // 构建财务数据文本
      final dataText = _buildFinancialDataText(data);
      
      // 构建提示词
      final prompt = AppConstants.financialAnalysisPrompt
          .replaceAll('{code}', code)
          .replaceAll('{name}', name)
          .replaceAll('{reportDate}', data.reportDate)
          .replaceAll('{data}', dataText);
      
      // 使用模拟分析
      return _mockFinancialAnalysis(data);
    } catch (e) {
      throw Exception('财务分析失败: $e');
    }
  }

  /// 分析公告
  Future<AnnouncementAnalysis> analyzeAnnouncement({
    required String code,
    required String name,
    required Announcement announcement,
  }) async {
    try {
      // 构建提示词
      final prompt = AppConstants.announcementAnalysisPrompt
          .replaceAll('{code}', code)
          .replaceAll('{name}', name)
          .replaceAll('{title}', announcement.title)
          .replaceAll('{time}', announcement.publishTime.toString())
          .replaceAll('{content}', announcement.content ?? '');
      
      // 使用模拟分析
      return _mockAnnouncementAnalysis(announcement);
    } catch (e) {
      throw Exception('公告分析失败: $e');
    }
  }

  /// 构建K线数据文本
  String _buildKLineDataText(List<KLineData> data) {
    final buffer = StringBuffer();
    buffer.writeln('日期        开盘    收盘    最高    最低    成交量');
    buffer.writeln('------------------------------------------------');
    
    // 取最近20条数据
    final recentData = data.length > 20 ? data.sublist(data.length - 20) : data;
    
    for (final item in recentData) {
      buffer.writeln(
        '${item.time.toString().substring(0, 10)}  '
        '${item.open.toStringAsFixed(2).padLeft(6)}  '
        '${item.close.toStringAsFixed(2).padLeft(6)}  '
        '${item.high.toStringAsFixed(2).padLeft(6)}  '
        '${item.low.toStringAsFixed(2).padLeft(6)}  '
        '${item.volume}'
      );
    }
    
    return buffer.toString();
  }

  /// 构建财务数据文本
  String _buildFinancialDataText(FinancialData data) {
    final buffer = StringBuffer();
    
    buffer.writeln('【利润表】');
    buffer.writeln('营业收入: ${data.revenue}万元 (同比${data.revenueYoy}%)');
    buffer.writeln('净利润: ${data.netProfit}万元 (同比${data.netProfitYoy}%)');
    buffer.writeln('毛利率: ${data.grossMargin}%');
    buffer.writeln('净利率: ${data.netMargin}%');
    buffer.writeln('');
    
    buffer.writeln('【资产负债表】');
    buffer.writeln('总资产: ${data.totalAssets}万元');
    buffer.writeln('总负债: ${data.totalLiabilities}万元');
    buffer.writeln('股东权益: ${data.equity}万元');
    buffer.writeln('资产负债率: ${data.debtRatio}%');
    buffer.writeln('');
    
    buffer.writeln('【关键指标】');
    buffer.writeln('每股收益(EPS): ${data.eps}元');
    buffer.writeln('净资产收益率(ROE): ${data.roe}%');
    buffer.writeln('总资产收益率(ROA): ${data.roa}%');
    buffer.writeln('流动比率: ${data.currentRatio}');
    buffer.writeln('速动比率: ${data.quickRatio}');
    buffer.writeln('');
    
    buffer.writeln('【现金流】');
    buffer.writeln('经营现金流: ${data.operatingCashFlow}万元');
    buffer.writeln('投资现金流: ${data.investingCashFlow}万元');
    buffer.writeln('筹资现金流: ${data.financingCashFlow}万元');
    
    return buffer.toString();
  }

  /// 模拟K线分析
  KLineAnalysis _mockKLineAnalysis(List<KLineData> data) {
    if (data.isEmpty) {
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
    
    final recent = data.sublist(data.length > 20 ? data.length - 20 : 0);
    final firstPrice = recent.first.close;
    final lastPrice = recent.last.close;
    final change = ((lastPrice - firstPrice) / firstPrice) * 100;
    
    // 趋势判断
    String trend;
    String trendDesc;
    if (change > 5) {
      trend = '上升趋势';
      trendDesc = '股价处于上升通道，近期涨幅${change.toStringAsFixed(2)}%，走势强劲';
    } else if (change < -5) {
      trend = '下降趋势';
      trendDesc = '股价处于下降通道，近期跌幅${change.abs().toStringAsFixed(2)}%，需要谨慎';
    } else {
      trend = '震荡整理';
      trendDesc = '股价在区间内震荡，近期波动${change.abs().toStringAsFixed(2)}%，等待方向选择';
    }
    
    // 形态识别
    final patterns = <String>[];
    final lastData = recent.last;
    
    // 检查锤子线
    final bodySize = (lastData.close - lastData.open).abs();
    final lowerShadow = lastData.isUp ? lastData.open - lastData.low : lastData.close - lastData.low;
    if (lowerShadow > bodySize * 2) {
      patterns.add('锤子线 - 可能出现反弹');
    }
    
    // 检查连续涨跌
    int upCount = 0;
    int downCount = 0;
    for (int i = recent.length - 1; i >= 0 && i >= recent.length - 5; i--) {
      if (recent[i].isUp) upCount++;
      if (recent[i].isDown) downCount++;
    }
    if (upCount >= 3) patterns.add('连续上涨$upCount天');
    if (downCount >= 3) patterns.add('连续下跌$downCount天');
    
    // 支撑阻力位
    final lows = recent.map((e) => e.low).toList()..sort();
    final highs = recent.map((e) => e.high).toList()..sort();
    final support = lows[lows.length ~/ 4];
    final resistance = highs[highs.length * 3 ~/ 4];
    
    // 技术指标总结
    String technicalSummary;
    if (trend == '上升趋势') {
      technicalSummary = '均线系统呈多头排列，MACD指标在零轴上方，整体技术面偏强';
    } else if (trend == '下降趋势') {
      technicalSummary = '均线系统呈空头排列，MACD指标在零轴下方，整体技术面偏弱';
    } else {
      technicalSummary = '均线系统纠缠，MACD在零轴附近，技术面处于盘整状态';
    }
    
    // 交易建议
    String advice;
    if (trend == '上升趋势') {
      if (lastPrice > resistance * 0.98) {
        advice = '建议持股观望，股价接近阻力位，突破后可加仓，回调至支撑位可考虑买入';
      } else {
        advice = '建议逢低买入，上升趋势明确，可在回调时逐步建仓';
      }
    } else if (trend == '下降趋势') {
      if (patterns.any((p) => p.contains('锤子线'))) {
        advice = '可能出现短期反弹，激进投资者可小仓位试探，稳健投资者继续观望';
      } else {
        advice = '建议观望或减仓，下降趋势未改，等待企稳信号';
      }
    } else {
      advice = '建议观望，震荡行情中等待方向明确，可在支撑位附近轻仓试探';
    }
    
    // 风险提示
    final risks = <String>[
      '股市有风险，投资需谨慎',
      '技术分析仅供参考，不构成投资建议',
    ];
    
    // 计算波动率
    final volatilities = recent.map((e) => (e.high - e.low) / e.open).toList();
    final avgVolatility = volatilities.reduce((a, b) => a + b) / volatilities.length;
    if (avgVolatility > 0.03) {
      risks.add('近期波动较大(${avgVolatility.toStringAsFixed(2)}%)，注意控制风险');
    }
    
    // 信心评分
    int confidence = 50;
    if (patterns.isNotEmpty) confidence += 15;
    if (trend != '震荡整理') confidence += 10;
    if (data.length >= 60) confidence += 10;
    confidence = confidence.clamp(0, 100);
    
    return KLineAnalysis(
      trend: trend,
      trendDescription: trendDesc,
      patterns: patterns,
      supportLevel: support,
      resistanceLevel: resistance,
      technicalSummary: technicalSummary,
      tradingAdvice: advice,
      confidenceScore: confidence,
      riskWarnings: risks,
    );
  }

  /// 模拟财务分析
  FinancialAnalysis _mockFinancialAnalysis(FinancialData data) {
    // 盈利能力分析
    String profitabilityAnalysis;
    if (data.roe > 15) {
      profitabilityAnalysis = '公司盈利能力优秀，ROE达到${data.roe}%，远超市场平均水平，说明股东权益回报率高。';
    } else if (data.roe > 10) {
      profitabilityAnalysis = '公司盈利能力良好，ROE为${data.roe}%，处于较好水平。';
    } else if (data.roe > 5) {
      profitabilityAnalysis = '公司盈利能力一般，ROE为${data.roe}%，仍有提升空间。';
    } else {
      profitabilityAnalysis = '公司盈利能力较弱，ROE仅为${data.roe}%，需要关注盈利改善情况。';
    }
    
    if (data.netMargin > 20) {
      profitabilityAnalysis += '净利率高达${data.netMargin}%，盈利质量优秀。';
    } else if (data.netMargin > 10) {
      profitabilityAnalysis += '净利率为${data.netMargin}%，盈利能力尚可。';
    }
    
    // 成长性分析
    String growthAnalysis;
    if (data.revenueYoy > 20 && data.netProfitYoy > 20) {
      growthAnalysis = '公司成长性优秀，营收增长${data.revenueYoy}%，净利润增长${data.netProfitYoy}%，处于高速成长阶段。';
    } else if (data.revenueYoy > 10 && data.netProfitYoy > 10) {
      growthAnalysis = '公司成长性良好，营收增长${data.revenueYoy}%，净利润增长${data.netProfitYoy}%，保持稳定增长。';
    } else if (data.revenueYoy > 0 && data.netProfitYoy > 0) {
      growthAnalysis = '公司成长性一般，营收增长${data.revenueYoy}%，净利润增长${data.netProfitYoy}%，增速放缓。';
    } else {
      growthAnalysis = '公司成长性面临挑战，营收增长${data.revenueYoy}%，净利润增长${data.netProfitYoy}%，需要关注业绩改善。';
    }
    
    // 偿债能力分析
    String solvencyAnalysis;
    if (data.debtRatio < 40) {
      solvencyAnalysis = '公司偿债能力强，资产负债率仅为${data.debtRatio}%，财务风险较低。';
    } else if (data.debtRatio < 60) {
      solvencyAnalysis = '公司偿债能力尚可，资产负债率为${data.debtRatio}%，处于合理区间。';
    } else {
      solvencyAnalysis = '公司偿债压力较大，资产负债率高达${data.debtRatio}%，需要关注债务风险。';
    }
    
    if (data.currentRatio > 2) {
      solvencyAnalysis += '流动比率为${data.currentRatio}，短期偿债能力充足。';
    } else if (data.currentRatio > 1) {
      solvencyAnalysis += '流动比率为${data.currentRatio}，短期偿债能力一般。';
    } else {
      solvencyAnalysis += '流动比率为${data.currentRatio}，短期偿债压力较大。';
    }
    
    // 运营效率分析
    String efficiencyAnalysis = '公司总资产周转率为${data.assetTurnover}，';
    if (data.assetTurnover > 0.8) {
      efficiencyAnalysis += '资产运营效率较高，资产利用充分。';
    } else if (data.assetTurnover > 0.5) {
      efficiencyAnalysis += '资产运营效率一般，仍有提升空间。';
    } else {
      efficiencyAnalysis += '资产运营效率较低，存在资产闲置。';
    }
    
    // 现金流分析
    String cashFlowAnalysis;
    if (data.operatingCashFlow > 0 && data.freeCashFlow > 0) {
      cashFlowAnalysis = '公司现金流状况良好，经营现金流为正，自由现金流充裕，财务质量健康。';
    } else if (data.operatingCashFlow > 0) {
      cashFlowAnalysis = '公司经营现金流为正，但自由现金流为负，可能存在较大的资本支出。';
    } else {
      cashFlowAnalysis = '公司经营现金流为负，需要关注现金创造能力，可能存在回款压力。';
    }
    
    // 投资建议
    String investmentAdvice;
    final healthScore = data.healthScore;
    if (healthScore >= 80) {
      investmentAdvice = '强烈推荐。公司基本面优秀，盈利能力强，成长性好，财务状况健康，适合长期持有。建议关注估值水平，在合理价位积极配置。';
    } else if (healthScore >= 60) {
      investmentAdvice = '推荐。公司基本面良好，各项指标处于合理水平，可以适当配置。建议关注行业景气度和公司业绩变化。';
    } else if (healthScore >= 40) {
      investmentAdvice = '中性。公司基本面一般，存在一些问题需要关注。建议观望，等待业绩改善或估值进一步回落后再考虑。';
    } else {
      investmentAdvice = '回避。公司基本面较差，存在较多风险点。建议谨慎对待，等待公司基本面明显改善后再考虑投资。';
    }
    
    return FinancialAnalysis(
      profitabilityAnalysis: profitabilityAnalysis,
      growthAnalysis: growthAnalysis,
      solvencyAnalysis: solvencyAnalysis,
      efficiencyAnalysis: efficiencyAnalysis,
      cashFlowAnalysis: cashFlowAnalysis,
      healthScore: data.healthScore,
      healthLevel: data.healthLevel,
      riskWarnings: data.riskPoints,
      investmentHighlights: data.highlights,
      investmentAdvice: investmentAdvice,
      summary: '综合来看，该公司财务${data.healthLevel}，${data.riskPoints.isEmpty ? "未发现明显风险" : "需关注${data.riskPoints.first}"}。',
    );
  }

  /// 模拟公告分析
  AnnouncementAnalysis _mockAnnouncementAnalysis(Announcement announcement) {
    // 根据标题关键词判断类型和情感
    final title = announcement.title.toLowerCase();
    
    String type;
    String typeDesc;
    String sentiment;
    int sentimentScore;
    List<String> keyPoints;
    String impactAnalysis;
    String shortTermImpact;
    String longTermImpact;
    String tradingAdvice;
    List<String> riskWarnings;
    
    // 业绩相关
    if (title.contains('业绩') || title.contains('净利润') || title.contains('营收')) {
      type = 'earnings';
      typeDesc = '业绩公告';
      
      if (title.contains('预增') || title.contains('增长') || title.contains('扭亏')) {
        sentiment = 'positive';
        sentimentScore = 60;
        keyPoints = [
          '公司业绩向好，盈利能力提升',
          '经营状况改善，业务发展顺利',
          '有利于提升投资者信心',
        ];
        impactAnalysis = '业绩改善是重大利好，说明公司基本面在好转。';
        shortTermImpact = '股价可能上涨，市场反应积极。';
        longTermImpact = '若业绩持续改善，将支撑股价长期走强。';
        tradingAdvice = '建议关注，可考虑逢低买入。但需结合估值水平，避免追高。';
        riskWarnings = ['关注业绩增长是否可持续', '注意估值是否已反映利好'];
      } else if (title.contains('预减') || title.contains('下降') || title.contains('亏损')) {
        sentiment = 'negative';
        sentimentScore = -50;
        keyPoints = [
          '公司业绩下滑，盈利能力下降',
          '经营状况面临挑战',
          '可能影响投资者信心',
        ];
        impactAnalysis = '业绩下滑是利空消息，需要关注下滑原因。';
        shortTermImpact = '股价可能承压下跌。';
        longTermImpact = '若业绩持续恶化，将对股价形成长期压力。';
        tradingAdvice = '建议观望，等待业绩企稳信号。持仓者可考虑减仓避险。';
        riskWarnings = ['业绩下滑风险', '可能存在进一步恶化的可能'];
      } else {
        sentiment = 'neutral';
        sentimentScore = 0;
        keyPoints = ['公司发布业绩相关公告', '需关注具体业绩数据'];
        impactAnalysis = '业绩公告，影响取决于具体数据。';
        shortTermImpact = '视业绩情况而定。';
        longTermImpact = '需结合行业和公司发展综合判断。';
        tradingAdvice = '建议等待业绩数据公布后，再做出投资决策。';
        riskWarnings = ['业绩不确定性'];
      }
    }
    // 分红相关
    else if (title.contains('分红') || title.contains('派息') || title.contains('送转')) {
      type = 'dividend';
      typeDesc = '分红配股';
      sentiment = 'positive';
      sentimentScore = 40;
      keyPoints = [
        '公司实施分红，回报股东',
        '体现公司现金流充裕',
        '有利于提升股票吸引力',
      ];
      impactAnalysis = '分红是利好，体现公司盈利能力和现金流状况良好。';
      shortTermImpact = '除权除息日股价会调整，但填权行情可期。';
      longTermImpact = '持续分红的公司更受长期投资者青睐。';
      tradingAdvice = '适合长期投资者持有，短期可关注填权机会。';
      riskWarnings = ['注意除权除息日股价调整', '高分红可能不可持续'];
    }
    // 重大事项
    else if (title.contains('重组') || title.contains('收购') || title.contains('合并')) {
      type = 'major';
      typeDesc = '重大事项';
      sentiment = 'positive';
      sentimentScore = 50;
      keyPoints = [
        '公司发生重大资本运作',
        '可能改变公司发展格局',
        '需要关注交易细节',
      ];
      impactAnalysis = '重大事项通常对股价有重大影响，具体取决于交易条款。';
      shortTermImpact = '股价可能出现较大波动。';
      longTermImpact = '若重组成功，可能带来质的飞跃。';
      tradingAdvice = '建议密切关注进展，谨慎参与。';
      riskWarnings = ['重组存在不确定性', '可能面临监管审批风险'];
    }
    // 股东变动
    else if (title.contains('减持') || title.contains('增持')) {
      type = 'shareholder';
      typeDesc = '股东变动';
      
      if (title.contains('增持')) {
        sentiment = 'positive';
        sentimentScore = 30;
        keyPoints = [
          '股东增持股份',
          '体现对公司发展信心',
          '有利于稳定股价',
        ];
        impactAnalysis = '股东增持是积极信号，显示内部人对公司前景看好。';
        shortTermImpact = '对股价有支撑作用。';
        longTermImpact = '若持续增持，表明长期看好。';
        tradingAdvice = '可参考股东增持价位，作为投资参考。';
        riskWarnings = ['关注增持是否完成', '增持规模大小影响力度'];
      } else {
        sentiment = 'negative';
        sentimentScore = -40;
        keyPoints = [
          '股东减持股份',
          '可能是资金需求或看淡后市',
          '对股价形成压力',
        ];
        impactAnalysis = '股东减持通常被视为利空，但需看减持原因。';
        shortTermImpact = '股价可能承压。';
        longTermImpact = '若大规模减持，需警惕。';
        tradingAdvice = '建议观望，等待减持压力释放。';
        riskWarnings = ['减持对股价形成压力', '可能存在持续减持风险'];
      }
    }
    // 其他类型
    else {
      type = 'other';
      typeDesc = '其他公告';
      sentiment = 'neutral';
      sentimentScore = 0;
      keyPoints = ['公司发布重要公告', '建议关注公告内容'];
      impactAnalysis = '公告影响需具体分析。';
      shortTermImpact = '视公告内容而定。';
      longTermImpact = '需结合公司整体情况判断。';
      tradingAdvice = '建议仔细阅读公告内容，理性分析影响。';
      riskWarnings = ['公告影响存在不确定性'];
    }
    
    return AnnouncementAnalysis(
      type: type,
      typeDescription: typeDesc,
      sentiment: sentiment,
      sentimentScore: sentimentScore,
      summary: '${announcement.title}，属于$typeDesc，整体判断为${sentimentScore > 20 ? '利好' : sentimentScore < -20 ? '利空' : '中性'}。',
      keyPoints: keyPoints,
      impactAnalysis: impactAnalysis,
      shortTermImpact: shortTermImpact,
      longTermImpact: longTermImpact,
      tradingAdvice: tradingAdvice,
      riskWarnings: riskWarnings,
      confidenceLevel: 70,
    );
  }
}
