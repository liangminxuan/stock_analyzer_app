/// 公告模型
class Announcement {
  final String id;                        // 公告ID
  final String code;                      // 股票代码
  final String name;                      // 股票名称
  final String title;                     // 公告标题
  final String? content;                  // 公告内容
  final String type;                      // 公告类型
  final DateTime publishTime;             // 发布时间
  final String? source;                   // 来源
  final String? url;                      // 原文链接
  final bool isImportant;                 // 是否重要公告
  final bool isRead;                      // 是否已读

  const Announcement({
    required this.id,
    required this.code,
    required this.name,
    required this.title,
    this.content,
    required this.type,
    required this.publishTime,
    this.source,
    this.url,
    this.isImportant = false,
    this.isRead = false,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      type: json['type'] as String? ?? 'other',
      publishTime: json['publishTime'] != null
          ? DateTime.parse(json['publishTime'] as String)
          : DateTime.now(),
      source: json['source'] as String?,
      url: json['url'] as String?,
      isImportant: (json['isImportant'] as bool?) ?? false,
      isRead: (json['isRead'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'title': title,
      'content': content,
      'type': type,
      'publishTime': publishTime.toIso8601String(),
      'source': source,
      'url': url,
      'isImportant': isImportant,
      'isRead': isRead,
    };
  }

  Announcement copyWith({
    String? id,
    String? code,
    String? name,
    String? title,
    String? content,
    String? type,
    DateTime? publishTime,
    String? source,
    String? url,
    bool? isImportant,
    bool? isRead,
  }) {
    return Announcement(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      publishTime: publishTime ?? this.publishTime,
      source: source ?? this.source,
      url: url ?? this.url,
      isImportant: isImportant ?? this.isImportant,
      isRead: isRead ?? this.isRead,
    );
  }

  /// 获取公告类型中文
  String get typeText {
    final typeMap = {
      'earnings': '业绩公告',
      'dividend': '分红配股',
      'major': '重大事项',
      'trading': '交易提示',
      'shareholder': '股东变动',
      'financing': '融资公告',
      'investment': '对外投资',
      'restructure': '资产重组',
      'lawsuit': '诉讼仲裁',
      'other': '其他公告',
    };
    return typeMap[type] ?? '其他公告';
  }

  /// 获取类型颜色
  String get typeColor {
    final colorMap = {
      'earnings': 'blue',
      'dividend': 'red',
      'major': 'orange',
      'trading': 'green',
      'shareholder': 'purple',
      'financing': 'cyan',
      'investment': 'indigo',
      'restructure': 'pink',
      'lawsuit': 'red',
      'other': 'gray',
    };
    return colorMap[type] ?? 'gray';
  }

  /// 格式化发布时间
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(publishTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${publishTime.month}/${publishTime.day}';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Announcement) return false;
    return id == other.id && code == other.code;
  }

  @override
  int get hashCode => Object.hash(id, code);

  @override
  String toString() {
    return 'Announcement(id: $id, code: $code, name: $name, title: $title, type: $type)';
  }
}

/// 公告分析结果
class AnnouncementAnalysis {
  final String type;                       // 公告类型
  final String typeDescription;            // 类型描述
  final String sentiment;                  // 情感倾向 (positive/negative/neutral)
  final int sentimentScore;                // 情感分数 (-100 到 100)
  final String summary;                    // 内容摘要
  final List<String> keyPoints;            // 关键要点
  final String impactAnalysis;             // 影响分析
  final String shortTermImpact;            // 短期影响
  final String longTermImpact;             // 长期影响
  final String tradingAdvice;              // 交易建议
  final List<String> riskWarnings;         // 风险提示
  final int confidenceLevel;               // 分析置信度 (0-100)

  const AnnouncementAnalysis({
    required this.type,
    required this.typeDescription,
    required this.sentiment,
    required this.sentimentScore,
    required this.summary,
    required this.keyPoints,
    required this.impactAnalysis,
    required this.shortTermImpact,
    required this.longTermImpact,
    required this.tradingAdvice,
    required this.riskWarnings,
    required this.confidenceLevel,
  });

  factory AnnouncementAnalysis.fromJson(Map<String, dynamic> json) {
    return AnnouncementAnalysis(
      type: json['type'] as String? ?? '',
      typeDescription: json['typeDescription'] as String? ?? '',
      sentiment: json['sentiment'] as String? ?? 'neutral',
      sentimentScore: (json['sentimentScore'] as int?) ?? 0,
      summary: json['summary'] as String? ?? '',
      keyPoints: (json['keyPoints'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      impactAnalysis: json['impactAnalysis'] as String? ?? '',
      shortTermImpact: json['shortTermImpact'] as String? ?? '',
      longTermImpact: json['longTermImpact'] as String? ?? '',
      tradingAdvice: json['tradingAdvice'] as String? ?? '',
      riskWarnings: (json['riskWarnings'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      confidenceLevel: (json['confidenceLevel'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'typeDescription': typeDescription,
      'sentiment': sentiment,
      'sentimentScore': sentimentScore,
      'summary': summary,
      'keyPoints': keyPoints,
      'impactAnalysis': impactAnalysis,
      'shortTermImpact': shortTermImpact,
      'longTermImpact': longTermImpact,
      'tradingAdvice': tradingAdvice,
      'riskWarnings': riskWarnings,
      'confidenceLevel': confidenceLevel,
    };
  }

  AnnouncementAnalysis copyWith({
    String? type,
    String? typeDescription,
    String? sentiment,
    int? sentimentScore,
    String? summary,
    List<String>? keyPoints,
    String? impactAnalysis,
    String? shortTermImpact,
    String? longTermImpact,
    String? tradingAdvice,
    List<String>? riskWarnings,
    int? confidenceLevel,
  }) {
    return AnnouncementAnalysis(
      type: type ?? this.type,
      typeDescription: typeDescription ?? this.typeDescription,
      sentiment: sentiment ?? this.sentiment,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      summary: summary ?? this.summary,
      keyPoints: keyPoints ?? this.keyPoints,
      impactAnalysis: impactAnalysis ?? this.impactAnalysis,
      shortTermImpact: shortTermImpact ?? this.shortTermImpact,
      longTermImpact: longTermImpact ?? this.longTermImpact,
      tradingAdvice: tradingAdvice ?? this.tradingAdvice,
      riskWarnings: riskWarnings ?? this.riskWarnings,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
    );
  }

  /// 是否利好
  bool get isPositive => sentimentScore > 20;

  /// 是否利空
  bool get isNegative => sentimentScore < -20;

  /// 是否中性
  bool get isNeutral => sentimentScore >= -20 && sentimentScore <= 20;

  /// 获取情感标签
  String get sentimentLabel {
    if (isPositive) return '利好';
    if (isNegative) return '利空';
    return '中性';
  }

  /// 获取情感颜色
  String get sentimentColor {
    if (isPositive) return 'red';
    if (isNegative) return 'green';
    return 'gray';
  }

  /// 获取建议颜色
  String get adviceColor {
    if (tradingAdvice.contains('买入') || tradingAdvice.contains('增持')) return 'red';
    if (tradingAdvice.contains('卖出') || tradingAdvice.contains('减持')) return 'green';
    return 'gray';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnnouncementAnalysis) return false;
    return type == other.type &&
        sentimentScore == other.sentimentScore &&
        tradingAdvice == other.tradingAdvice;
  }

  @override
  int get hashCode => Object.hash(type, sentimentScore, tradingAdvice);

  @override
  String toString() {
    return 'AnnouncementAnalysis(type: $type, sentiment: $sentiment, '
        'sentimentScore: $sentimentScore, tradingAdvice: $tradingAdvice)';
  }
}

/// 公告筛选条件
class AnnouncementFilter {
  final String? code;                              // 股票代码
  final String? type;                              // 公告类型
  final DateTime? startDate;                       // 开始日期
  final DateTime? endDate;                         // 结束日期
  final bool onlyImportant;                        // 仅重要公告
  final String sortBy;                             // 排序方式
  final String sortOrder;                          // 排序方向

  const AnnouncementFilter({
    this.code,
    this.type,
    this.startDate,
    this.endDate,
    this.onlyImportant = false,
    this.sortBy = 'time',
    this.sortOrder = 'desc',
  });

  factory AnnouncementFilter.fromJson(Map<String, dynamic> json) {
    return AnnouncementFilter(
      code: json['code'] as String?,
      type: json['type'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      onlyImportant: (json['onlyImportant'] as bool?) ?? false,
      sortBy: json['sortBy'] as String? ?? 'time',
      sortOrder: json['sortOrder'] as String? ?? 'desc',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'type': type,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'onlyImportant': onlyImportant,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    };
  }

  AnnouncementFilter copyWith({
    String? code,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    bool? onlyImportant,
    String? sortBy,
    String? sortOrder,
  }) {
    return AnnouncementFilter(
      code: code ?? this.code,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      onlyImportant: onlyImportant ?? this.onlyImportant,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnnouncementFilter) return false;
    return code == other.code &&
        type == other.type &&
        onlyImportant == other.onlyImportant &&
        sortBy == other.sortBy &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => Object.hash(code, type, onlyImportant, sortBy, sortOrder);

  @override
  String toString() {
    return 'AnnouncementFilter(code: $code, type: $type, onlyImportant: $onlyImportant, '
        'sortBy: $sortBy, sortOrder: $sortOrder)';
  }
}

/// 公告统计
class AnnouncementStats {
  final int totalCount;                   // 总公告数
  final int todayCount;                   // 今日公告数
  final Map<String, int> typeDistribution; // 类型分布
  final List<Announcement> importantList;  // 重要公告列表

  const AnnouncementStats({
    required this.totalCount,
    required this.todayCount,
    required this.typeDistribution,
    required this.importantList,
  });

  factory AnnouncementStats.fromJson(Map<String, dynamic> json) {
    final typeDist = <String, int>{};
    final rawTypeDist = json['typeDistribution'] as Map<String, dynamic>?;
    if (rawTypeDist != null) {
      rawTypeDist.forEach((key, value) {
        typeDist[key] = (value as num).toInt();
      });
    }

    final important = (json['importantList'] as List<dynamic>?)
            ?.map((e) => Announcement.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return AnnouncementStats(
      totalCount: (json['totalCount'] as int?) ?? 0,
      todayCount: (json['todayCount'] as int?) ?? 0,
      typeDistribution: typeDist,
      importantList: important,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCount': totalCount,
      'todayCount': todayCount,
      'typeDistribution': typeDistribution,
      'importantList': importantList.map((e) => e.toJson()).toList(),
    };
  }

  AnnouncementStats copyWith({
    int? totalCount,
    int? todayCount,
    Map<String, int>? typeDistribution,
    List<Announcement>? importantList,
  }) {
    return AnnouncementStats(
      totalCount: totalCount ?? this.totalCount,
      todayCount: todayCount ?? this.todayCount,
      typeDistribution: typeDistribution ?? this.typeDistribution,
      importantList: importantList ?? this.importantList,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnnouncementStats) return false;
    return totalCount == other.totalCount && todayCount == other.todayCount;
  }

  @override
  int get hashCode => Object.hash(totalCount, todayCount);

  @override
  String toString() {
    return 'AnnouncementStats(totalCount: $totalCount, todayCount: $todayCount, '
        'typeDistribution: ${typeDistribution.length} types)';
  }
}

/// 公告类型定义
class AnnouncementTypes {
  static const String earnings = 'earnings';       // 业绩公告
  static const String dividend = 'dividend';       // 分红配股
  static const String major = 'major';             // 重大事项
  static const String trading = 'trading';         // 交易提示
  static const String shareholder = 'shareholder'; // 股东变动
  static const String financing = 'financing';     // 融资公告
  static const String investment = 'investment';   // 对外投资
  static const String restructure = 'restructure'; // 资产重组
  static const String lawsuit = 'lawsuit';         // 诉讼仲裁
  static const String other = 'other';             // 其他公告

  static const Map<String, String> typeNames = {
    earnings: '业绩公告',
    dividend: '分红配股',
    major: '重大事项',
    trading: '交易提示',
    shareholder: '股东变动',
    financing: '融资公告',
    investment: '对外投资',
    restructure: '资产重组',
    lawsuit: '诉讼仲裁',
    other: '其他公告',
  };

  static const Map<String, String> typeColors = {
    earnings: '#3498DB',
    dividend: '#E74C3C',
    major: '#F39C12',
    trading: '#27AE60',
    shareholder: '#9B59B6',
    financing: '#1ABC9C',
    investment: '#5D6D7E',
    restructure: '#E91E63',
    lawsuit: '#E74C3C',
    other: '#95A5A6',
  };

  static String getName(String type) => typeNames[type] ?? '其他公告';
  static String getColor(String type) => typeColors[type] ?? '#95A5A6';
}
