import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_widget.dart';

/// 财报中心页面 - 显示股票财报数据
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StockApiService _apiService = StockApiService();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // 模拟财报数据
  final List<Map<String, dynamic>> _financialReports = [
    {
      'title': '2024年第三季度报告',
      'stockName': '贵州茅台',
      'stockCode': '600519',
      'date': '2024-10-30',
      'type': '季报',
      'summary': '营收同比增长15.3%，净利润增长18.2%',
    },
    {
      'title': '2024年半年度报告',
      'stockName': '宁德时代',
      'stockCode': '300750',
      'date': '2024-08-25',
      'type': '半年报',
      'summary': '新能源汽车电池出货量全球第一',
    },
    {
      'title': '2024年第一季度报告',
      'stockName': '中国平安',
      'stockCode': '601318',
      'date': '2024-04-28',
      'type': '季报',
      'summary': '保险业务稳健增长，投资收益改善',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchStock() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _apiService.searchStocks(keyword);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('财报中心'),
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),

          // 搜索结果或财报列表
          Expanded(
            child: _hasSearched ? _buildSearchResults() : _buildReportList(),
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索股票查看财报',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _hasSearched = false;
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onSubmitted: (_) => _searchStock(),
            ),
          ),
          SizedBox(width: 12.w),
          ElevatedButton(
            onPressed: _isSearching ? null : _searchStock,
            child: _isSearching
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('搜索'),
          ),
        ],
      ),
    );
  }

  /// 构建搜索结果
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: LoadingWidget());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text('未找到相关股票', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final stock = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              stock['code']?.toString().substring(0, 1) ?? '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(stock['name'] ?? ''),
          subtitle: Text('${stock['code']} (${stock['market'] == 'sh' ? '上证' : '深证'})'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // 显示该股票的财报
            _showStockFinance(stock);
          },
        );
      },
    );
  }

  /// 显示股票财报
  void _showStockFinance(Map<String, dynamic> stock) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock['name'] ?? '未知',
                            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            stock['code'] ?? '',
                            style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  '主要财务指标',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                _buildFinanceMetrics(),
                SizedBox(height: 24.h),
                Text(
                  '历史财报',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildReportCard('2024年第三季度报告', '2024-10-30', '营收同比+15.3%', stock),
                      _buildReportCard('2024年半年度报告', '2024-08-25', '净利润同比+18.2%', stock),
                      _buildReportCard('2024年第一季度报告', '2024-04-28', '扣非净利润+12.5%', stock),
                      _buildReportCard('2023年年度报告', '2024-03-30', '分红方案：每10股派50元', stock),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建财务指标
  Widget _buildFinanceMetrics() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          _buildMetricRow('每股收益(EPS)', '15.23元'),
          _buildMetricRow('市盈率(PE)', '28.5倍'),
          _buildMetricRow('市净率(PB)', '8.2倍'),
          _buildMetricRow('净资产收益率(ROE)', '25.3%'),
          _buildMetricRow('毛利率', '91.5%'),
          _buildMetricRow('资产负债率', '18.2%'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReportCard(String title, String date, String summary, Map<String, dynamic> stock) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(summary),
        trailing: Text(date, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        onTap: () {
          // 显示财报详情（不是股票K线）
          _showReportDetail(title, date, summary, stock);
        },
      ),
    );
  }

  /// 显示财报详情
  void _showReportDetail(String title, String date, String summary, Map<String, dynamic> stock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: 16.sp)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${stock['name']} (${stock['code']})', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              Text('发布日期: $date'),
              SizedBox(height: 16.h),
              Text('报告摘要', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              Text(summary),
              SizedBox(height: 16.h),
              Text('主要数据', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              _buildDetailRow('营业收入', '120.5亿元', '+15.3%'),
              _buildDetailRow('净利润', '45.2亿元', '+18.2%'),
              _buildDetailRow('扣非净利润', '42.8亿元', '+12.5%'),
              _buildDetailRow('基本每股收益', '3.52元', '+10.0%'),
              SizedBox(height: 16.h),
              Text('AI解读', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '本季度业绩表现优异，营收和净利润均实现双位数增长，超出市场预期。毛利率保持稳定，费用控制良好。建议关注后续季度业绩持续性。',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, String change) {
    final isPositive = change.startsWith('+');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Row(
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(width: 8.w),
              Text(
                change,
                style: TextStyle(
                  color: isPositive ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建财报列表
  Widget _buildReportList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: _financialReports.length,
      itemBuilder: (context, index) {
        final report = _financialReports[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: ListTile(
            contentPadding: EdgeInsets.all(16.w),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    report['type'] ?? '报告',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    report['title'] ?? '',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                Text(
                  '${report['stockName']} (${report['stockCode']})',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 4.h),
                Text(
                  report['summary'] ?? '',
                  style: TextStyle(fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  report['date'] ?? '',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ],
            ),
            onTap: () {
              // 显示财报详情（不是股票K线）
              _showReportDetail(
                report['title'] ?? '',
                report['date'] ?? '',
                report['summary'] ?? '',
                {'name': report['stockName'], 'code': report['stockCode']},
              );
            },
          ),
        );
      },
    );
  }
}
