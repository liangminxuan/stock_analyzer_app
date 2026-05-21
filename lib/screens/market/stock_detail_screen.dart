import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/stock.dart';
import '../../models/kline.dart';
import '../../providers/stock_provider.dart';
import '../../widgets/loading_widget.dart';

/// 股票详情页 - 使用新浪K线图片
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
  String _currentPeriod = 'daily'; // daily, weekly, monthly

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<StockProvider>();
    String pureCode = widget.stockCode;
    if (pureCode.startsWith('sh') || pureCode.startsWith('sz')) {
      pureCode = pureCode.substring(2);
    }
    print('[StockDetailScreen] 加载数据: $pureCode');
    await provider.fetchStockDetail(pureCode);
  }

  /// 获取新浪K线图片URL
  String _getKLineImageUrl(String period) {
    // 新浪K线图片接口
    // daily: 日K, weekly: 周K, monthly: 月K
    final marketCode = widget.stockCode; // 已经是 sh/sz 前缀格式
    return 'https://image.sinajs.cn/newchart/$period/n/$marketCode.gif';
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
                  
                  // K线图片
                  _buildKLineImage(),
                  
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
    final periodCodes = ['min', 'daily', 'weekly', 'monthly'];
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _currentPeriod == periodCodes[index];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentPeriod = periodCodes[index];
                });
              },
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
  }

  /// 构建K线图片（新浪图片）
  Widget _buildKLineImage() {
    final imageUrl = _getKLineImageUrl(_currentPeriod);
    print('[StockDetailScreen] K线图片: $imageUrl');
    
    return Container(
      height: 300.h,
      padding: EdgeInsets.all(16.w),
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('[StockDetailScreen] K线图片加载失败: $error');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48.sp, color: Colors.grey),
                SizedBox(height: 8.h),
                Text('K线图片加载失败', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        },
      ),
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

    // 传纯代码给 analyzeKLine
    String pureCode = widget.stockCode;
    if (pureCode.startsWith('sh') || pureCode.startsWith('sz')) {
      pureCode = pureCode.substring(2);
    }
    
    print('[StockDetailScreen] AI分析: $pureCode');
    await provider.analyzeKLine(pureCode, widget.stockName);

    if (context.mounted) {
      Navigator.pop(context);
      
      final analysis = provider.klineAnalysis;
      if (analysis != null) {
        _showAnalysisResult(context, analysis);
      } else {
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI分析失败，请稍后重试')),
        );
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
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI智能分析',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildAnalysisSection('趋势判断', analysis.trend, analysis.trendDescription),
                  _buildAnalysisSection('技术指标', analysis.technicalSummary, ''),
                  _buildAnalysisSection('交易建议', analysis.tradingAdvice, ''),
                  if (analysis.patterns.isNotEmpty)
                    _buildAnalysisSection('形态识别', analysis.patterns.join('、'), ''),
                  if (analysis.riskWarnings.isNotEmpty)
                    _buildAnalysisSection('风险提示', analysis.riskWarnings.join('、'), ''),
                  SizedBox(height: 16.h),
                  Text(
                    '免责声明：以上分析仅供参考，不构成投资建议',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalysisSection(String title, String content, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            content,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建盘口数据
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
              Expanded(
                child: _buildOrderBookSide('卖', stock.askPrices.reversed.toList(), stock.askVolumes.reversed.toList(), false),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildOrderBookSide('买', stock.bidPrices, stock.bidVolumes, true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookSide(String label, List<double> prices, List<int> volumes, bool isBuy) {
    return Column(
      children: List.generate(5, (index) {
        final price = index < prices.length ? prices[index] : 0.0;
        final volume = index < volumes.length ? volumes[index] : 0;
        final color = isBuy ? AppTheme.upColor : AppTheme.downColor;
        
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$label${5 - index}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
              Text(
                price.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: price > 0 ? color : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                volume > 0 ? (volume / 100).toStringAsFixed(0) : '-',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
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
          _buildInfoRow('股票代码', '${stock.market}${stock.code}'),
          _buildInfoRow('市盈率', stock.pe?.toStringAsFixed(2) ?? '-'),
          _buildInfoRow('总市值', stock.marketCapText),
        ],
      ),
    );
  }

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
              color: Colors.grey,
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

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
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
