import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../services/backend_service.dart';

/// AI 对冲基金选股分析页面
/// 基于 virattt/ai-hedge-fund 项目的策略
/// 使用 GetX 状态管理
class AIAnalysisScreen extends StatelessWidget {
  const AIAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 确保控制器已注册
    return GetBuilder<AIAnalysisController>(
      init: AIAnalysisController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'AI 对冲基金分析',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
          ),
          body: Obx(() {
            if (controller.isLoading.value) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: 16.h),
                    Text(
                      controller.loadingMessage.value,
                      style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            if (controller.hasError.value) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64.sp, color: Colors.grey),
                    SizedBox(height: 16.h),
                    Text(
                      controller.errorMessage.value,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => controller.startAnalysis(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            if (controller.analysisData.value == null) {
              return _buildInputView(context, controller);
            }

            return _buildResultView(context, controller);
          }),
        );
      },
    );
  }

  /// 输入视图
  Widget _buildInputView(BuildContext context, AIAnalysisController controller) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部介绍卡片
          _buildIntroCard(context),
          SizedBox(height: 24.h),

          // 股票代码输入
          Text(
            '输入股票代码',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          _buildStockInput(context),
          SizedBox(height: 24.h),

          // 开始分析按钮
          _buildStartButton(context),
          SizedBox(height: 24.h),

          // 策略说明
          _buildStrategyDescription(context),
        ],
      ),
    );
  }

  /// 介绍卡片
  Widget _buildIntroCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 对冲基金选股分析',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '基于 virattt/ai-hedge-fund 策略引擎',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '融合 5 大量化策略 + 基本面分析 + 风险管理，提供专业级选股建议',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 股票代码输入
  Widget _buildStockInput(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller.codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '请输入股票代码，如 600036',
              hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, size: 20.sp, color: Colors.grey[400]),
              counterText: '',
            ),
            onChanged: (value) => controller.stockCode.value = value.trim(),
          ),
        ),
        SizedBox(width: 12.w),
        ElevatedButton(
          onPressed: controller.startAnalysis,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text(
            '开始分析',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// 开始分析按钮（底部大按钮）
  Widget _buildStartButton(BuildContext context) {
    return ElevatedButton(
      onPressed: controller.stockCode.value.length == 6
          ? controller.startAnalysis
          : null,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 48.h),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      child: const Text('开始 AI 分析', style: TextStyle(fontSize: 16)),
    );
  }

  /// 策略说明
  Widget _buildStrategyDescription(BuildContext context) {
    final strategies = [
      {'name': '趋势跟踪', 'en': 'Trend Following', 'icon': Icons.trending_up, 'desc': '基于 EMA/SMA 均线系统判断趋势方向'},
      {'name': '均值回归', 'en': 'Mean Reversion', 'icon': Icons.swap_vert, 'desc': '识别价格偏离均值后的回归机会'},
      {'name': '动量分析', 'en': 'Momentum', 'icon': Icons.speed, 'desc': '捕捉价格动量变化和趋势强度'},
      {'name': '波动率分析', 'en': 'Volatility', 'icon': Icons.show_chart, 'desc': '基于波动率指标评估风险收益比'},
      {'name': '统计套利', 'en': 'Statistical Arbitrage', 'icon': Icons.calculate, 'desc': '利用统计模型发现定价偏差'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分析策略',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.h),
        ...strategies.map((s) => Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    s['icon'] as IconData,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s['name'] as String,
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            s['en'] as String,
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        s['desc'] as String,
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  /// 结果视图
  Widget _buildResultView(BuildContext context, AIAnalysisController controller) {
    final data = controller.analysisData.value!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 股票信息头部
          _buildStockHeader(context, data),
          SizedBox(height: 20.h),

          // 综合评分仪表盘
          _buildOverallGauge(context, data),
          SizedBox(height: 20.h),

          // 操作建议
          _buildActionCard(context, data),
          SizedBox(height: 24.h),

          // 技术分析区域
          _buildSectionTitle(context, '技术分析', Icons.candlestick_chart),
          SizedBox(height: 12.h),
          _buildTechnicalStrategies(context, data),
          SizedBox(height: 24.h),

          // 基本面分析区域
          _buildSectionTitle(context, '基本面分析', Icons.account_balance),
          SizedBox(height: 12.h),
          _buildFundamentalAnalysis(context, data),
          SizedBox(height: 24.h),

          // 风险管理区域
          _buildSectionTitle(context, '风险管理', Icons.shield),
          SizedBox(height: 12.h),
          _buildRiskManagement(context, data),
          SizedBox(height: 32.h),

          // 重新分析按钮
          OutlinedButton.icon(
            onPressed: () {
              controller.analysisData.value = null;
              controller.codeController.clear();
              controller.stockCode.value = '';
            },
            icon: const Icon(Icons.refresh),
            label: const Text('分析其他股票'),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, 44.h),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  /// 股票信息头部
  Widget _buildStockHeader(BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.business, color: Theme.of(context).colorScheme.primary, size: 28.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['name'] ?? ''}（${data['code'] ?? ''}）',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4.h),
                Text(
                  'AI 对冲基金综合分析报告',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 24.sp),
        ],
      ),
    );
  }

  /// 综合评分仪表盘
  Widget _buildOverallGauge(BuildContext context, Map<String, dynamic> data) {
    final overall = data['overall'] as Map<String, dynamic>?;
    if (overall == null) return const SizedBox.shrink();

    final signal = overall['signal'] as String? ?? 'neutral';
    final confidence = (overall['confidence'] as num?)?.toDouble() ?? 0.0;
    final score = (overall['score'] as num?)?.toDouble() ?? 0.0;
    final description = overall['description'] as String? ?? '';

    final signalColor = _getSignalColor(signal);
    final signalText = _getSignalText(signal);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '综合评分',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          SizedBox(height: 20.h),

          // 仪表盘
          SizedBox(
            width: 200.w,
            height: 120.h,
            child: CustomPaint(
              painter: _GaugePainter(
                value: score.clamp(-1.0, 1.0),
                color: signalColor,
              ),
            ),
          ),

          SizedBox(height: 8.h),

          // 信号文字
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: signalColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              signalText,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: signalColor,
              ),
            ),
          ),

          SizedBox(height: 8.h),

          // 描述
          if (description.isNotEmpty)
            Text(
              description,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),

          SizedBox(height: 16.h),

          // 置信度
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '置信度',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: confidence,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(signalColor),
                    minHeight: 6.h,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: signalColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 操作建议卡片
  Widget _buildActionCard(BuildContext context, Map<String, dynamic> data) {
    final action = data['action'] as Map<String, dynamic>?;
    if (action == null) return const SizedBox.shrink();

    final recommendation = action['recommendation'] as String? ?? '';
    final detail = action['detail'] as String? ?? '';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.08),
            Theme.of(context).colorScheme.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Theme.of(context).colorScheme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                '操作建议',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (recommendation.isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                recommendation,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          if (detail.isNotEmpty)
            Text(
              detail,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700], height: 1.6),
            ),
        ],
      ),
    );
  }

  /// 区域标题
  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// 技术分析策略卡片
  Widget _buildTechnicalStrategies(BuildContext context, Map<String, dynamic> data) {
    final technical = data['technical'] as Map<String, dynamic>?;
    if (technical == null) return const SizedBox.shrink();

    final strategies = technical['strategies'] as Map<String, dynamic>?;
    if (strategies == null) return const SizedBox.shrink();

    final strategyConfig = [
      {'key': 'trend', 'name': '趋势跟踪', 'en': 'Trend Following', 'icon': Icons.trending_up},
      {'key': 'mean_reversion', 'name': '均值回归', 'en': 'Mean Reversion', 'icon': Icons.swap_vert},
      {'key': 'momentum', 'name': '动量分析', 'en': 'Momentum', 'icon': Icons.speed},
      {'key': 'volatility', 'name': '波动率分析', 'en': 'Volatility', 'icon': Icons.show_chart},
      {'key': 'stat_arb', 'name': '统计套利', 'en': 'Statistical Arbitrage', 'icon': Icons.calculate},
    ];

    return Column(
      children: strategyConfig.map((config) {
        final key = config['key'] as String;
        final strategyData = strategies[key] as Map<String, dynamic>?;
        if (strategyData == null) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: _buildStrategyCard(
            context: context,
            name: config['name'] as String,
            englishName: config['en'] as String,
            icon: config['icon'] as IconData,
            signal: strategyData['signal'] as String? ?? 'neutral',
            confidence: (strategyData['confidence'] as num?)?.toDouble() ?? 0.0,
            details: strategyData['details'] as String? ?? '',
          ),
        );
      }).toList(),
    );
  }

  /// 单个策略卡片
  Widget _buildStrategyCard({
    required BuildContext context,
    required String name,
    required String englishName,
    required IconData icon,
    required String signal,
    required double confidence,
    required String details,
  }) {
    final signalColor = _getSignalColor(signal);
    final signalText = _getSignalText(signal);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // 标题行
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: signalColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: signalColor, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      englishName,
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // 信号指示器
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: signalColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: signalColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      signalText,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: signalColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 置信度条
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Row(
              children: [
                Text(
                  '置信度',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3.r),
                    child: LinearProgressIndicator(
                      value: confidence,
                      backgroundColor: Colors.grey.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(signalColor),
                      minHeight: 5.h,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${(confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: signalColor,
                  ),
                ),
              ],
            ),
          ),

          // 详情
          if (details.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                details,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 基本面分析
  Widget _buildFundamentalAnalysis(BuildContext context, Map<String, dynamic> data) {
    final fundamental = data['fundamental'] as Map<String, dynamic>?;
    if (fundamental == null) return const SizedBox.shrink();

    final dimensions = [
      {'key': 'profitability', 'name': '盈利能力', 'en': 'Profitability', 'icon': Icons.monetization_on},
      {'key': 'growth', 'name': '成长性', 'en': 'Growth', 'icon': Icons.trending_up},
      {'key': 'financial_health', 'name': '财务健康', 'en': 'Financial Health', 'icon': Icons.favorite},
      {'key': 'valuation', 'name': '估值比率', 'en': 'Valuation', 'icon': Icons.balance},
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        children: dimensions.map((dim) {
          final key = dim['key'] as String;
          final dimData = fundamental[key] as Map<String, dynamic>?;
          if (dimData == null) return const SizedBox.shrink();

          final signal = dimData['signal'] as String? ?? 'neutral';
          final confidence = (dimData['confidence'] as num?)?.toDouble() ?? 0.0;
          final score = (dimData['score'] as num?)?.toDouble() ?? 0.0;
          final signalColor = _getSignalColor(signal);
          final signalText = _getSignalText(signal);

          return Column(
            children: [
              if (dim != dimensions.first)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: Divider(height: 1.h, color: Colors.grey.withOpacity(0.15)),
                ),
              Row(
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: signalColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(dim['icon'] as IconData, color: signalColor, size: 18.sp),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              dim['name'] as String,
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              dim['en'] as String,
                              style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            // 信号标签
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: signalColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                signalText,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: signalColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            // 评分
                            Text(
                              '评分: ${score.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                            ),
                            SizedBox(width: 10.w),
                            // 置信度
                            Text(
                              '置信度: ${(confidence * 100).toStringAsFixed(0)}%',
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 风险管理区域
  Widget _buildRiskManagement(BuildContext context, Map<String, dynamic> data) {
    final risk = data['risk'] as Map<String, dynamic>?;
    if (risk == null) return const SizedBox.shrink();

    final annualizedVolatility = (risk['annualized_volatility'] as num?)?.toDouble() ?? 0.0;
    final maxDrawdown = (risk['max_drawdown'] as num?)?.toDouble() ?? 0.0;
    final riskLevel = risk['risk_level'] as String? ?? '未知';
    final positionLimit = (risk['position_limit_pct'] as num?)?.toDouble() ?? 0.0;

    // 根据风险等级确定颜色
    Color riskColor;
    if (riskLevel.contains('低')) {
      riskColor = const Color(0xFF27AE60); // 绿色
    } else if (riskLevel.contains('高')) {
      riskColor = const Color(0xFFE74C3C); // 红色
    } else {
      riskColor = const Color(0xFFF39C12); // 橙色
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // 风险等级卡片
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: riskColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield, color: riskColor, size: 28.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '风险等级',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        riskLevel,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.warning_amber_rounded, color: riskColor, size: 32.sp),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // 风险指标网格
          Row(
            children: [
              Expanded(
                child: _buildRiskMetricCard(
                  context: context,
                  label: '年化波动率',
                  value: '${annualizedVolatility.toStringAsFixed(1)}%',
                  icon: Icons.show_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildRiskMetricCard(
                  context: context,
                  label: '最大回撤',
                  value: '${maxDrawdown.toStringAsFixed(1)}%',
                  icon: Icons.trending_down,
                  color: const Color(0xFFE74C3C),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // 仓位建议
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Icon(Icons.pie_chart, color: Theme.of(context).colorScheme.primary, size: 22.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '建议仓位上限',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            positionLimit.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              height: 1,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Padding(
                            padding: EdgeInsets.only(bottom: 4.h),
                            child: Text(
                              '%',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 60.w,
                  height: 60.w,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: positionLimit / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Center(
                        child: Text(
                          '${positionLimit.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 风险指标卡片
  Widget _buildRiskMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取信号颜色
  /// bullish = 绿色（国际惯例），bearish = 红色，neutral = 灰色
  static Color _getSignalColor(String signal) {
    switch (signal.toLowerCase()) {
      case 'bullish':
        return const Color(0xFF27AE60);
      case 'bearish':
        return const Color(0xFFE74C3C);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  /// 获取信号中文文本
  static String _getSignalText(String signal) {
    switch (signal.toLowerCase()) {
      case 'bullish':
        return '看多';
      case 'bearish':
        return '看空';
      default:
        return '中性';
    }
  }
}

/// 仪表盘绘制器
class _GaugePainter extends CustomPainter {
  final double value; // -1.0 ~ 1.0
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.42;

    const startAngle = pi;
    const endAngle = 2 * pi;

    // 背景弧
    final bgPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      endAngle - startAngle,
      false,
      bgPaint,
    );

    // 值弧
    final normalizedValue = (value + 1) / 2; // -1~1 -> 0~1
    final valueAngle = startAngle + normalizedValue * (endAngle - startAngle);

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      valueAngle - startAngle,
      false,
      valuePaint,
    );

    // 指针
    final pointerLength = radius - 20;
    final pointerAngle = valueAngle;
    final pointerEnd = Offset(
      center.dx + pointerLength * cos(pointerAngle),
      center.dy + pointerLength * sin(pointerAngle),
    );

    final pointerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, pointerEnd, pointerPaint);

    // 中心圆点
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 5, dotPaint);

    // 标签
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 左标签 "看空"
    textPainter.text = TextSpan(
      text: '看空',
      style: TextStyle(color: const Color(0xFFE74C3C), fontSize: 11),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - radius - 5, center.dy + 12),
    );

    // 右标签 "看多"
    textPainter.text = TextSpan(
      text: '看多',
      style: TextStyle(color: const Color(0xFF27AE60), fontSize: 11),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx + radius - 20, center.dy + 12),
    );

    // 中间标签 "中性"
    textPainter.text = TextSpan(
      text: '中性',
      style: TextStyle(color: const Color(0xFF7F8C8D), fontSize: 11),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - 10, center.dy + 12),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

/// AI 分析控制器
class AIAnalysisController extends GetxController {
  final BackendService _backendService = BackendService();

  final TextEditingController codeController = TextEditingController();
  final stockCode = ''.obs;
  final isLoading = false.obs;
  final loadingMessage = '正在分析中...'.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;
  final analysisData = Rx<Map<String, dynamic>?>(null);

  /// 开始分析
  Future<void> startAnalysis() async {
    final code = stockCode.value.trim();
    if (code.length != 6) {
      hasError.value = true;
      errorMessage.value = '请输入正确的6位股票代码';
      return;
    }

    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';
    loadingMessage.value = '正在获取 $code 的 AI 分析数据...';

    try {
      final response = await _backendService.dio.get(
        '/api/stock/ai_analysis',
        queryParameters: {'code': code},
      );

      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        analysisData.value = Map<String, dynamic>.from(data);
      } else {
        hasError.value = true;
        errorMessage.value = data['message'] as String? ?? '分析失败，请稍后重试';
      }
    } catch (e) {
      print('[AIAnalysis] 分析失败: $e');
      hasError.value = true;
      errorMessage.value = '网络请求失败，请检查网络连接后重试';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    codeController.dispose();
    super.onClose();
  }
}
