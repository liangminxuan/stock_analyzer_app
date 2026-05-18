import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/market_provider.dart';
import '../../widgets/stock_card.dart';
import '../../widgets/loading_widget.dart';
import 'search_screen.dart';
import 'stock_detail_screen.dart';

/// 行情页面
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().fetchHotStocks();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '行情中心',
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
      body: Column(
        children: [
          // 分类标签
          _buildCategoryTabs(),
          
          // 表头
          _buildTableHeader(),
          
          // 股票列表
          Expanded(
            child: Consumer<MarketProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.hotStocks.isEmpty) {
                  return const LoadingWidget();
                }

                if (provider.error != null && provider.hotStocks.isEmpty) {
                  return _buildErrorWidget(provider.error!);
                }

                if (provider.hotStocks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 64.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          '暂无股票数据',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.fetchHotStocks(),
                  child: ListView.builder(
                    itemCount: provider.hotStocks.length,
                    itemBuilder: (context, index) {
                      final stock = provider.hotStocks[index];
                      return StockCard(
                        stock: stock,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StockDetailScreen(
                                stockCode: stock.fullCode,
                                stockName: stock.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类标签
  Widget _buildCategoryTabs() {
    final categories = ['全部', '沪市', '深市', '创业板', '科创板'];
    
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == 0;
          return Container(
            margin: EdgeInsets.only(right: 12.w),
            child: FilterChip(
              label: Text(categories[index]),
              selected: isSelected,
              onSelected: (selected) {
                // TODO: 切换分类
              },
            ),
          );
        },
      ),
    );
  }

  /// 构建表头
  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '名称/代码',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '最新价',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '涨跌幅',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
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
            size: 64.sp,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(height: 16.h),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 16.sp,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              context.read<MarketProvider>().fetchHotStocks();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
