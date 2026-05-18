import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/routes.dart';

/// 选股页面
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _isLoading = false;
  String _selectedStrategy = 'all';

  final strategies = [
    {'id': 'all', 'name': '综合选股', 'desc': '多维度筛选', 'icon': Icons.auto_awesome},
    {'id': 'value', 'name': '价值优选', 'desc': '低估值高分红', 'icon': Icons.savings},
    {'id': 'growth', 'name': '成长先锋', 'desc': '高成长潜力股', 'icon': Icons.trending_up},
    {'id': 'tech', 'name': '技术突破', 'desc': '突破关键位', 'icon': Icons.candlestick_chart},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '智能选股',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI选股卡片
            _buildAIPickerCard(),
            
            SizedBox(height: 24.h),
            
            // 选择策略
            _buildStrategySelector(),
            
            SizedBox(height: 24.h),
            
            // 筛选条件预览
            _buildFilterPreview(),
            
            SizedBox(height: 24.h),
            
            // 热门策略
            _buildStrategySection(),
          ],
        ),
      ),
    );
  }

  /// 构建AI选股卡片
  Widget _buildAIPickerCard() {
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
                      'AI智能选股',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '基于多维度数据智能筛选优质股票',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _isLoading ? null : _startStockSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: Size(double.infinity, 44.h),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : const Text('开始选股'),
          ),
        ],
      ),
    );
  }

  /// 开始选股
  void _startStockSelection() async {
    setState(() {
      _isLoading = true;
    });

    // 模拟选股过程
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // 显示选股结果对话框
    _showStockSelectionResult();
  }

  /// 显示选股结果
  void _showStockSelectionResult() {
    // 推荐的示例股票
    final recommendedStocks = [
      {'name': '贵州茅台', 'code': '600519', 'reason': '价值投资首选'},
      {'name': '宁德时代', 'code': '300750', 'reason': '新能源龙头'},
      {'name': '招商银行', 'code': '600036', 'reason': '银行稳健标的'},
      {'name': '比亚迪', 'code': '002594', 'reason': '新能源车领导者'},
      {'name': '中国平安', 'code': '601318', 'reason': '保险行业龙头'},
    ];

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'AI选股结果',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  '基于 $_selectedStrategy 策略，为您筛选出以下股票',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: recommendedStocks.length,
                    itemBuilder: (context, index) {
                      final stock = recommendedStocks[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(stock['name']!),
                        subtitle: Text('${stock['code']} • ${stock['reason']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            Routes.stockDetail,
                            arguments: {
                              'code': '${stock['code']!.startsWith('6') ? 'sh' : 'sz'}${stock['code']}',
                              'name': stock['name'],
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建策略选择器
  Widget _buildStrategySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择策略',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: strategies.map((strategy) {
              final isSelected = _selectedStrategy == strategy['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedStrategy = strategy['id'] as String;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(right: 12.w),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: isSelected
                        ? Border.all(color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        strategy['icon'] as IconData,
                        size: 20.sp,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        strategy['name'] as String,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 构建筛选条件预览
  Widget _buildFilterPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '筛选条件',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _buildFilterChip('市盈率 < 30'),
            _buildFilterChip('市净率 < 5'),
            _buildFilterChip('ROE > 10%'),
            _buildFilterChip('流通市值 > 100亿'),
            _buildFilterChip('换手率 > 2%'),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }

  /// 构建热门策略
  Widget _buildStrategySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '热门策略',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: [
            _buildStrategyCard('价值投资', '低估值稳健', Icons.savings),
            _buildStrategyCard('成长投资', '高增长潜力', Icons.trending_up),
            _buildStrategyCard('技术分析', '趋势跟踪', Icons.candlestick_chart),
            _buildStrategyCard('资金流向', '机构动向', Icons.account_balance),
          ],
        ),
      ],
    );
  }

  Widget _buildStrategyCard(String name, String desc, IconData icon) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56.w) / 2,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 28.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            name,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
