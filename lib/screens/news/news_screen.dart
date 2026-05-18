import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

/// 公告解读页面
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StockApiService _apiService = StockApiService();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // 模拟公告数据
  final List<Map<String, dynamic>> _announcements = [
    {
      'title': '关于2024年度利润分配预案的公告',
      'stockName': '贵州茅台',
      'stockCode': '600519',
      'date': '2024-03-30',
      'type': '分红公告',
      'summary': '每10股派发现金红利50元（含税）',
    },
    {
      'title': '关于与某新能源汽车公司签订战略合作协议的公告',
      'stockName': '宁德时代',
      'stockCode': '300750',
      'date': '2024-02-15',
      'type': '重大合同',
      'summary': '预计合同金额超过100亿元',
    },
    {
      'title': '关于2024年第一季度业绩预告',
      'stockName': '中国平安',
      'stockCode': '601318',
      'date': '2024-04-10',
      'type': '业绩预告',
      'summary': '净利润同比增长10%-15%',
    },
    {
      'title': '关于控股股东增持公司股份的公告',
      'stockName': '五粮液',
      'stockCode': '000858',
      'date': '2024-01-20',
      'type': '增减持',
      'summary': '控股股东增持公司股份100万股',
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
        title: const Text('公告解读'),
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          
          // 搜索结果或公告列表
          Expanded(
            child: _hasSearched ? _buildSearchResults() : _buildAnnouncementList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索股票查看公告',
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

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
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
            _showStockAnnouncements(stock);
          },
        );
      },
    );
  }

  void _showStockAnnouncements(Map<String, dynamic> stock) {
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
                  '最新公告',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12.h),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildAnnouncementCard(
                        '关于2024年第三季度报告的公告',
                        '2024-10-30',
                        '定期报告',
                        '公司第三季度实现营业收入...',
                      ),
                      _buildAnnouncementCard(
                        '关于召开2024年第三次临时股东大会的通知',
                        '2024-10-15',
                        '股东大会',
                        '审议关于公司2024年度投资计划的议案...',
                      ),
                      _buildAnnouncementCard(
                        '关于获得政府补助的公告',
                        '2024-09-28',
                        '其他公告',
                        '公司近日收到政府补助资金5000万元...',
                      ),
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

  Widget _buildAnnouncementCard(String title, String date, String type, String summary) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.w),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),
            Text(
              summary,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey),
                SizedBox(width: 4.w),
                Text(
                  date,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          _showAnnouncementDetail(title, date, type, summary);
        },
      ),
    );
  }

  void _showAnnouncementDetail(String title, String date, String type, String summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: 16.sp)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(type),
                    backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  ),
                  SizedBox(width: 8.w),
                  Text(date, style: TextStyle(color: Colors.grey)),
                ],
              ),
              SizedBox(height: 16.h),
              Text(
                '公告摘要',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
              SizedBox(height: 8.h),
              Text(summary),
              SizedBox(height: 16.h),
              Text(
                'AI解读',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '该公告属于$type，对公司影响偏正面。建议关注后续进展。',
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

  Widget _buildAnnouncementList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final announcement = _announcements[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12.h),
          child: ListTile(
            contentPadding: EdgeInsets.all(16.w),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    announcement['type'] ?? '公告',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    announcement['title'] ?? '',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                Text(
                  '${announcement['stockName']} (${announcement['stockCode']})',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 4.h),
                Text(
                  announcement['summary'] ?? '',
                  style: TextStyle(fontSize: 13.sp),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey),
                    SizedBox(width: 4.w),
                    Text(
                      announcement['date'] ?? '',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {
              _showAnnouncementDetail(
                announcement['title'] ?? '',
                announcement['date'] ?? '',
                announcement['type'] ?? '公告',
                announcement['summary'] ?? '',
              );
            },
          ),
        );
      },
    );
  }
}
