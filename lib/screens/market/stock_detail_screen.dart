import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/stock.dart';
import '../../models/kline.dart';
import '../../providers/stock_provider.dart';
import '../../widgets/kline_chart.dart';
import '../../widgets/loading_widget.dart';

/// 股票详情页
class StockDetailScreen extends StatefulWidget {
  final String stockCode;
  final String stockName;

  const StockDetailScreen({
    super.key,
    required this.stockCode,
    required this.stockName,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<StockProvider>();
    await provider.fetchStockDetail(widget.stockCode);
    await provider.fetchKLineData(code: widget.stockCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.stockName,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.stockCode,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Consumer<StockProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentStock == null) {
            return const LoadingWidget();
          }

          if (provider.error != null && provider.currentStock == null) {
            return _buildErrorWidget(provider.error!);
          }

          final stock = provider.currentStock;
          if (stock == null) {
            return const Center(child: Text('暂无数据'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // 价格信息
                  _buildPriceHeader(stock),
                  
                  // 周期切换
                  _buildPeriodSelector(),
                  
                  // K线图
                  _buildKLineChart(),
                  
                  // AI分析按钮
                  _buildAIAnalysisButton(),
                  
                  // 盘口数据
                  _buildOrderBook(stock),
                  
                  // 基本信息
                  _buildStockInfo(stock),
                  
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建价格头部
  Widget _buildPriceHeader(Stock stock) {
    final color = stock.isUp ? AppTheme.upColor : 
                  stock.isDown ? AppTheme.downColor : AppTheme.neutralColor;
    
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stock.priceText,
                style: TextStyle(
                  fontSize: 40.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.changeText,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    stock.changePercentText,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem('最高', stock.highPrice.toStringAsFixed(2)),
              _buildInfoItem('最低', stock.lowPrice.toStringAsFixed(2)),
              _buildInfoItem('今开', stock.openPrice.toStringAsFixed(2)),
              _buildInfoItem('昨收', stock.previousClose.toStringAsFixed(2)),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem('成交量', stock.volumeText),
              _buildInfoItem('成交额', stock.turnoverText),
              _buildInfoItem('市值', stock.marketCapText),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建周期选择器
  Widget _buildPeriodSelector() {
    final periods = ['分时', '日K', '周K', '月K'];
    final periodCodes = ['min', 'day', 'week', 'month'];
    
    return Consumer<StockProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: List.generate(periods.length, (index) {
              final isSelected = provider.currentPeriod == periodCodes[index];
              return Expanded(
                child: GestureDetector(
                  onTap: () => provider.switchPeriod(periodCodes[index]),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      periods[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// 构建K线图
  Widget _buildKLineChart() {
    return Consumer<StockProvider>(
      builder: (context, provider, child) {
        if (provider.klineData.isEmpty) {
          return Container(
            height: 300.h,
            alignment: Alignment.center,
            child: const Text('暂无K线数据'),
          );
        }

        return Container(
          height: 400.h,
          padding: EdgeInsets.all(16.w),
          child: KLineChart(
            data: provider.klineData,
            onTap: (index) {
              // TODO: 显示选中K线详情
            },
          ),
        );
      },
    );
  }

  /// 构建AI分析按钮
  Widget _buildAIAnalysisButton() {
    return Consumer<StockProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: ElevatedButton.icon(
            onPressed: provider.isLoading
                ? null
                : () => _showAIAnalysis(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI智能分析'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 48.h),
            ),
          ),
        );
      },
    );
  }

  /// 显示AI分析
  void _showAIAnalysis(BuildContext context) async {
    final provider = context.read<StockProvider>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('AI分析中...'),
          ],
        ),
      ),
    );

    await provider.analyzeKLine(widget.stockCode, widget.stockName);

    if (context.mounted) {
      Navigator.pop(context);
      
      final analysis = provider.klineAnalysis;
      if (analysis != null) {
        _showAnalysisResult(context, analysis);
      }
    }
  }

  /// 显示分析结果
  void _showAnalysisResult(BuildContext context, KLineAnalysis analysis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: EdgeInsets.all(16.w),
            child: ListView(
              controller: scrollController,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'AI分析结果',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '信心度: ${analysis.confidenceScore}%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                
                // 趋势判断
                _buildAnalysisSection('趋势判断', analysis.trendDescription),
                
                // 形态识别
                if (analysis.patterns.isNotEmpty)
                  _buildAnalysisSection(
                    '形态识别',
                    analysis.patterns.join('\n'),
                  ),
                
                // 支撑阻力
                _buildAnalysisSection(
                  '支撑与阻力',
                  '支撑位: ${analysis.supportLevel.toStringAsFixed(2)}\n'
                  '阻力位: ${analysis.resistanceLevel.toStringAsFixed(2)}',
                ),
                
                // 技术指标
                _buildAnalysisSection('技术指标', analysis.technicalSummary),
                
                // 交易建议
                _buildAnalysisSection('交易建议', analysis.tradingAdvice, isHighlight: true),
                
                // 风险提示
                if (analysis.riskWarnings.isNotEmpty)
                  _buildAnalysisSection(
                    '风险提示',
                    analysis.riskWarnings.join('\n'),
                    isWarning: true,
                  ),
                
                SizedBox(height: 24.h),
                
                // 免责声明
                Text(
                  '免责声明：以上分析仅供参考，不构成投资建议。股市有风险，投资需谨慎。',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建分析区块
  Widget _buildAnalysisSection(String title, String content, {
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

  /// 构建盘口
  Widget _buildOrderBook(Stock stock) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '五档盘口',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              // 卖盘
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final price = stock.askPrices.reversed.toList()[index];
                    final volume = stock.askVolumes.reversed.toList()[index];
                    return _buildOrderBookRow(
                      '卖${5 - index}',
                      price,
                      volume,
                      AppTheme.downColor,
                    );
                  }),
                ),
              ),
              SizedBox(width: 16.w),
              // 买盘
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final price = stock.bidPrices[index];
                    final volume = stock.bidVolumes[index];
                    return _buildOrderBookRow(
                      '买${index + 1}',
                      price,
                      volume,
                      AppTheme.upColor,
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建盘口行
  Widget _buildOrderBookRow(String label, double price, int volume, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              price.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13.sp,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            volume.toString(),
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建股票信息
  Widget _buildStockInfo(Stock stock) {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '基本信息',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          _buildInfoRow('股票代码', stock.code),
          _buildInfoRow('所属市场', stock.market == 'sh' ? '上海证券交易所' : '深圳证券交易所'),
          if (stock.industry != null)
            _buildInfoRow('所属行业', stock.industry!),
          _buildInfoRow('市盈率', stock.peRatio > 0 ? stock.peRatio.toStringAsFixed(2) : '-'),
          _buildInfoRow('市净率', stock.pbRatio > 0 ? stock.pbRatio.toStringAsFixed(2) : '-'),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建错误组件
  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48.sp,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(height: 16.h),
          Text(error),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
