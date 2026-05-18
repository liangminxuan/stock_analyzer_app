import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../config/theme.dart';

/// AI分析卡片组件
class AIAnalysisCard extends StatelessWidget {
  final String title;
  final String content;
  final String? subTitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const AIAnalysisCard({
    super.key,
    required this.title,
    required this.content,
    this.subTitle,
    this.icon = Icons.auto_awesome,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: cardColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: cardColor.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    icon,
                    color: cardColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subTitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subTitle!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              content,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// AI分析结果展示组件
class AIAnalysisResult extends StatelessWidget {
  final String type; // kline, financial, announcement
  final Map<String, dynamic> data;

  const AIAnalysisResult({
    super.key,
    required this.type,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'kline':
        return _buildKLineAnalysis(context);
      case 'financial':
        return _buildFinancialAnalysis(context);
      case 'announcement':
        return _buildAnnouncementAnalysis(context);
      default:
        return const SizedBox.shrink();
    }
  }

  /// 构建K线分析结果
  Widget _buildKLineAnalysis(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(context, '趋势判断', data['trendDescription'] ?? ''),
        if ((data['patterns'] as List?)?.isNotEmpty == true)
          _buildSection(context, '形态识别', (data['patterns'] as List).join('\n')),
        _buildSection(context, '技术指标', data['technicalSummary'] ?? ''),
        _buildSection(context, '交易建议', data['tradingAdvice'] ?? '', isHighlight: true),
        if ((data['riskWarnings'] as List?)?.isNotEmpty == true)
          _buildSection(context, '风险提示', (data['riskWarnings'] as List).join('\n'), isWarning: true),
      ],
    );
  }

  /// 构建财务分析结果
  Widget _buildFinancialAnalysis(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScoreCard(context, data['healthScore'] ?? 0, data['healthLevel'] ?? '一般'),
        _buildSection(context, '盈利能力', data['profitabilityAnalysis'] ?? ''),
        _buildSection(context, '成长性分析', data['growthAnalysis'] ?? ''),
        _buildSection(context, '偿债能力', data['solvencyAnalysis'] ?? ''),
        _buildSection(context, '投资建议', data['investmentAdvice'] ?? '', isHighlight: true),
      ],
    );
  }

  /// 构建公告分析结果
  Widget _buildAnnouncementAnalysis(BuildContext context) {
    final sentiment = data['sentiment'] ?? 'neutral';
    final sentimentColor = sentiment == 'positive' 
        ? AppTheme.upColor 
        : sentiment == 'negative' 
            ? AppTheme.downColor 
            : AppTheme.neutralColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 16.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: sentimentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(
                sentiment == 'positive' 
                    ? Icons.trending_up 
                    : sentiment == 'negative' 
                        ? Icons.trending_down 
                        : Icons.trending_flat,
                color: sentimentColor,
              ),
              SizedBox(width: 8.w),
              Text(
                '情感倾向: ${data['sentimentLabel'] ?? '中性'}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: sentimentColor,
                ),
              ),
            ],
          ),
        ),
        _buildSection(context, '核心要点', (data['keyPoints'] as List?)?.join('\n') ?? ''),
        _buildSection(context, '影响分析', data['impactAnalysis'] ?? ''),
        _buildSection(context, '操作建议', data['tradingAdvice'] ?? '', isHighlight: true),
      ],
    );
  }

  /// 构建评分卡片
  Widget _buildScoreCard(BuildContext context, int score, String level) {
    Color scoreColor;
    if (score >= 80) {
      scoreColor = AppTheme.success;
    } else if (score >= 60) {
      scoreColor = AppTheme.warning;
    } else {
      scoreColor = AppTheme.error;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            height: 80.w,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: scoreColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        score.toString(),
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        '分',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: scoreColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '财务健康度',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建章节
  Widget _buildSection(BuildContext context, String title, String content, {
    bool isHighlight = false,
    bool isWarning = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isHighlight
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : isWarning
                ? AppTheme.error.withOpacity(0.05)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: isHighlight || isWarning
            ? Border.all(
                color: isHighlight
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                    : AppTheme.error.withOpacity(0.3),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isWarning ? AppTheme.error : null,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 14.sp,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
