import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/market_provider.dart';
import '../../models/stock.dart';
import '../../widgets/stock_card.dart';
import '../../widgets/loading_widget.dart';
import '../market/search_screen.dart';
import '../market/market_screen.dart';
import '../discovery/discovery_screen.dart';

/// 首页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<MarketProvider>();
    try {
      await provider.fetchMarketIndices();
    } catch (e) {
      print('[HomeScreen] Failed to load indices: $e');
    }
    try {
      await provider.fetchHotStocks();
    } catch (e) {
      print('[HomeScreen] Failed to load hot stocks: $e');
    }
  }

  void _navigateToStockDetail(Stock stock) {
    Navigator.pushNamed(
      context,
      Routes.stockDetail,
      arguments: {
        'code': stock.fullCode,
        'name': stock.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '股票分析助手',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 大盘指数
              _buildMarketIndices(),
              
              SizedBox(height: 16.h),
              
              // 功能入口
              _buildFeatureGrid(),
              
              SizedBox(height: 16.h),
              
              // 热门股票
              _buildHotStocks(),
              
              SizedBox(height: 16.h),
              
              // AI分析入口
              _buildAIAnalysisCard(),
              
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建大盘指数
  Widget _buildMarketIndices() {
    return Consumer<MarketProvider>(
      builder: (context, provider, child) {
        // 显示加载状态
        if (provider.isLoading && provider.indices.isEmpty) {
          return Container(
            height: 120.h,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }

        // 显示错误但有数据时，仍然显示数据
        if (provider.indices.isEmpty) {
          return Container(
            height: 120.h,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.grey, size: 32.sp),
                SizedBox(height: 8.h),
                Text(
                  '无法加载大盘指数',
                  style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                ),
                if (provider.error != null)
                  Text(
                    provider.error!,
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        }

        return Container(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: provider.indices.map((index) {
                return _buildIndexCard(index);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// 构建指数卡片
  Widget _buildIndexCard(MarketIndex index) {
    final color = index.isUp ? AppTheme.upColor : 
                  index.isDown ? AppTheme.downColor : AppTheme.neutralColor;
    
    return Container(
      width: 140.w,
      margin: EdgeInsets.only(right: 12.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index.name.isNotEmpty ? index.name : '未知指数',
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            index.currentPoint > 0 ? index.pointText : '--',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: index.currentPoint > 0 ? color : Colors.grey,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Icon(
                index.isUp ? Icons.arrow_upward : 
                index.isDown ? Icons.arrow_downward : Icons.remove,
                color: color,
                size: 14.sp,
              ),
              SizedBox(width: 4.w),
              Text(
                index.changePercent != 0 ? index.changePercentText : '--',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建功能入口
  Widget _buildFeatureGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '功能服务',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureItem(Icons.candlestick_chart, 'K线分析', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketScreen()));
              }),
              _buildFeatureItem(Icons.account_balance, '财报解读', () {
                Navigator.pushNamed(context, Routes.finance);
              }),
              _buildFeatureItem(Icons.article, '公告解读', () {
                Navigator.pushNamed(context, Routes.news);
              }),
              _buildFeatureItem(Icons.psychology, '智能选股', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72.w,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 32.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建热门股票
  Widget _buildHotStocks() {
    return Consumer<MarketProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '热门股票',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketScreen()));
                    },
                    child: const Text('查看更多'),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (provider.isLoading && provider.hotStocks.isEmpty)
                const LoadingWidget(height: 200)
              else if (provider.error != null && provider.hotStocks.isEmpty)
                _buildErrorWidget(provider.error!)
              else if (provider.hotStocks.isEmpty)
                Container(
                  height: 200.h,
                  alignment: Alignment.center,
                  child: Text(
                    '暂无热门股票数据',
                    style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.hotStocks.take(5).length,
                  itemBuilder: (context, index) {
                    final stock = provider.hotStocks[index];
                    return StockCard(
                      stock: stock,
                      onTap: () => _navigateToStockDetail(stock),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建AI分析卡片
  Widget _buildAIAnalysisCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen()));
        },
        child: Container(
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
          child: Row(
            children: [
              Container(
                width: 60.w,
                height: 60.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 32.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI智能分析',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'K线解读 · 财报分析 · 公告解读',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建错误组件
  Widget _buildErrorWidget(String error) {
    return Container(
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.error,
            size: 24.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.error,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<MarketProvider>().clearError();
              _loadData();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
