/// 应用常量配置
class AppConstants {
  AppConstants._();
  
  // 应用信息
  static const String appName = '股票分析助手';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI驱动的股票投资分析工具';
  
  // API基础URL
  static const String sinaApiBase = 'http://hq.sinajs.cn';
  static const String tencentApiBase = 'https://qt.gtimg.cn';
  static const String eastmoneyApiBase = 'https://push2.eastmoney.com';
  static const String eastmoneyKLineBase = 'https://push2his.eastmoney.com';
  
  // 缓存配置
  static const Duration cacheValidDuration = Duration(minutes: 5);
  static const int maxCacheSize = 100;
  
  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // 股票代码前缀
  static const String shPrefix = 'sh';  // 上海
  static const String szPrefix = 'sz';  // 深圳
  static const String bjPrefix = 'bj';  // 北京
  
  // 市场代码映射
  static const Map<String, String> marketNames = {
    'sh': '上海',
    'sz': '深圳',
    'bj': '北京',
  };
  
  // K线周期
  static const Map<String, String> kLinePeriods = {
    '1min': '1分钟',
    '5min': '5分钟',
    '15min': '15分钟',
    '30min': '30分钟',
    '60min': '60分钟',
    'day': '日线',
    'week': '周线',
    'month': '月线',
  };
  
  // 技术指标
  static const List<String> technicalIndicators = [
    'MA',      // 移动平均线
    'MACD',    // 指数平滑异同平均线
    'KDJ',     // 随机指标
    'RSI',     // 相对强弱指标
    'BOLL',    // 布林带
    'VOL',     // 成交量
  ];
  
  // 财务指标说明
  static const Map<String, String> financialIndicators = {
    'revenue': '营业收入',
    'netProfit': '净利润',
    'totalAssets': '总资产',
    'totalLiabilities': '总负债',
    'equity': '股东权益',
    'eps': '每股收益',
    'roe': '净资产收益率',
    'roa': '总资产收益率',
    'grossMargin': '毛利率',
    'netMargin': '净利率',
    'debtRatio': '资产负债率',
    'currentRatio': '流动比率',
    'quickRatio': '速动比率',
  };
  
  // AI分析提示词模板
  static const String kLineAnalysisPrompt = '''
你是一位专业的股票技术分析师，请对以下K线数据进行技术分析：

股票代码: {code}
股票名称: {name}
数据周期: {period}

K线数据（最近20个交易日）:
{data}

请从以下几个方面进行分析：
1. 趋势判断：当前处于上升、下降还是震荡趋势？
2. 形态识别：是否有明显的技术形态（如头肩顶/底、双顶/底、三角形等）？
3. 支撑与阻力：关键的支撑位和阻力位在哪里？
4. 技术指标：基于价格走势的技术指标解读
5. 操作建议：给出明确的操作建议（买入/卖出/观望），并说明理由

请用通俗易懂的语言，适合股市小白理解。
''';

  static const String financialAnalysisPrompt = '''
你是一位专业的财务分析师，请对以下财务数据进行解读：

股票代码: {code}
股票名称: {name}
报告期: {reportDate}

财务数据:
{data}

请从以下几个方面进行分析：
1. 盈利能力：公司的盈利能力如何？与上期相比有何变化？
2. 成长性：营收和利润的增长情况如何？
3. 偿债能力：公司的债务风险如何？
4. 运营效率：资产运营效率如何？
5. 财务健康度：给出一个综合评分（0-100分）
6. 风险提示：是否存在财务风险？
7. 投资建议：基于财务数据给出投资建议

请用通俗易懂的语言，适合股市小白理解。
''';

  static const String announcementAnalysisPrompt = '''
你是一位专业的财经资讯分析师，请对以下公告进行解读：

股票代码: {code}
股票名称: {name}
公告标题: {title}
公告时间: {time}

公告内容:
{content}

请从以下几个方面进行分析：
1. 公告类型：这是什么类型的公告？
2. 利好/利空：这是利好消息还是利空消息？程度如何？
3. 核心要点：公告的核心内容是什么？
4. 影响分析：对股价可能产生什么影响？短期和长期影响分别如何？
5. 操作建议：投资者应该如何应对？

请用通俗易懂的语言，适合股市小白理解。
''';
}

/// 股票类型枚举
enum StockType {
  aStock('A股'),
  hStock('港股'),
  usStock('美股'),
  indexStock('指数'),
  fund('基金'),
  etf('ETF');
  
  final String label;
  const StockType(this.label);
}

/// K线周期枚举
enum KLinePeriod {
  min1('1min', 1),
  min5('5min', 5),
  min15('15min', 15),
  min30('30min', 30),
  min60('60min', 60),
  day('day', 101),
  week('week', 102),
  month('month', 103);
  
  final String code;
  final int value;
  const KLinePeriod(this.code, this.value);
}

/// 排序方式枚举
enum SortType {
  priceAsc('价格从低到高'),
  priceDesc('价格从高到低'),
  changeAsc('涨幅从小到大'),
  changeDesc('涨幅从大到小'),
  volumeAsc('成交量从小到大'),
  volumeDesc('成交量从大到小'),
  marketCapAsc('市值从小到大'),
  marketCapDesc('市值从大到小');
  
  final String label;
  const SortType(this.label);
}
