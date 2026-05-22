import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/api_service.dart';
import '../../services/backend_service.dart';

/// 公告解读页面 - 从后端获取实时公告数据
/// 公告列表支持点击查看详情
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StockApiService _apiService = StockApiService();
  final BackendService _backendService = BackendService();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // 后端公告数据
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoadingAnnouncements = true;
  String? _announcementsError;
  int _currentPage = 1;
  int _totalAnnouncements = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 从后端加载今日公告
  Future<void> _loadAnnouncements({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoadingAnnouncements = true;
        _announcementsError = null;
        _currentPage = 1;
      });
    }

    try {
      final now = DateTime.now();
      final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final result = await _backendService.getAnnouncements(
        date: date,
        page: _currentPage,
        size: 20,
      );

      if (result.isEmpty && _currentPage == 1) {
        // 今天可能没有公告，尝试昨天
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayDate = '${yesterday.year}${yesterday.month.toString().padLeft(2, '0')}${yesterday.day.toString().padLeft(2, '0')}';
        final yesterdayResult = await _backendService.getAnnouncements(
          date: yesterdayDate,
          page: 1,
          size: 20,
        );
        setState(() {
          _announcements = yesterdayResult;
          _isLoadingAnnouncements = false;
          _hasMore = false;
        });
        return;
      }

      setState(() {
        if (_currentPage == 1) {
          _announcements = result;
        } else {
          _announcements.addAll(result);
        }
        _isLoadingAnnouncements = false;
        _hasMore = result.length >= 20;
      });
    } catch (e) {
      setState(() {
        _announcementsError = '加载公告失败，请检查网络连接';
        _isLoadingAnnouncements = false;
      });
    }
  }

  /// 搜索股票
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

  /// 搜索公告（按关键词）
  Future<void> _searchAnnouncements() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoadingAnnouncements = true;
      _hasSearched = true;
      _announcementsError = null;
    });

    try {
      final now = DateTime.now();
      final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final result = await _backendService.getAnnouncements(
        date: date,
        keyword: keyword,
        page: 1,
        size: 20,
      );

      // 如果今天没搜到，尝试最近几天
      if (result.isEmpty) {
        for (int i = 1; i <= 3; i++) {
          final pastDate = now.subtract(Duration(days: i));
          final pastDateStr = '${pastDate.year}${pastDate.month.toString().padLeft(2, '0')}${pastDate.day.toString().padLeft(2, '0')}';
          final pastResult = await _backendService.getAnnouncements(
            date: pastDateStr,
            keyword: keyword,
            page: 1,
            size: 20,
          );
          if (pastResult.isNotEmpty) {
            setState(() {
              _announcements = pastResult;
              _isLoadingAnnouncements = false;
            });
            return;
          }
        }
      }

      setState(() {
        _announcements = result;
        _isLoadingAnnouncements = false;
      });
    } catch (e) {
      setState(() {
        _announcementsError = '搜索公告失败';
        _isLoadingAnnouncements = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告解读'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadAnnouncements(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),

          // 内容区域
          Expanded(
            child: _hasSearched
                ? _buildSearchResults()
                : _buildAnnouncementList(),
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
                hintText: '搜索股票名称/代码查看公告',
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
              onSubmitted: (_) {
                // 判断输入是股票代码还是公告关键词
                final text = _searchController.text.trim();
                if (text.length == 6 && RegExp(r'^\d+$').hasMatch(text)) {
                  _searchStock();
                } else {
                  _searchAnnouncements();
                }
              },
            ),
          ),
          SizedBox(width: 12.w),
          ElevatedButton(
            onPressed: _isSearching ? null : () {
              final text = _searchController.text.trim();
              if (text.length == 6 && RegExp(r'^\d+$').hasMatch(text)) {
                _searchStock();
              } else {
                _searchAnnouncements();
              }
            },
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

    // 如果是公告关键词搜索结果
    if (_searchResults.isEmpty && _announcements.isNotEmpty) {
      return _buildAnnouncementListView();
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text('未找到相关股票或公告', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
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

  /// 显示个股公告（从后端获取）
  void _showStockAnnouncements(Map<String, dynamic> stock) {
    final code = stock['code']?.toString() ?? '';
    final name = stock['name']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _StockAnnouncementSheet(
        code: code,
        name: name,
        backendService: _backendService,
      ),
    );
  }

  Widget _buildAnnouncementList() {
    if (_isLoadingAnnouncements) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_announcementsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(_announcementsError!, style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => _loadAnnouncements(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text('暂无公告数据', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
            SizedBox(height: 8.h),
            Text('请搜索股票名称或代码查看相关公告', style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
          ],
        ),
      );
    }

    return _buildAnnouncementListView();
  }

  Widget _buildAnnouncementListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification && _hasMore) {
          final metrics = notification.metrics;
          if (metrics.maxScrollExtent - metrics.pixels < 200) {
            setState(() => _currentPage++);
            _loadAnnouncements();
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _announcements.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _announcements.length) {
            return Padding(
              padding: EdgeInsets.all(16.w),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          final announcement = _announcements[index];
          return _buildAnnouncementCard(
            title: announcement['title'] ?? '',
            date: announcement['date'] ?? '',
            type: announcement['type'] ?? '公告',
            stockName: announcement['name'] ?? '',
            stockCode: announcement['code'] ?? '',
            url: announcement['url'] ?? '',
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard({
    required String title,
    required String date,
    required String type,
    required String stockName,
    required String stockCode,
    String url = '',
  }) {
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
              '$stockName ($stockCode)',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 4.h),
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
          _showAnnouncementDetail(
            title: title,
            date: date,
            type: type,
            stockName: stockName,
            stockCode: stockCode,
            url: url,
          );
        },
      ),
    );
  }

  void _showAnnouncementDetail({
    required String title,
    required String date,
    required String type,
    required String stockName,
    required String stockCode,
    String url = '',
  }) {
    // 如果有URL，显示原文解读弹窗
    if (url.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => _AnnouncementDetailSheet(
          title: title,
          date: date,
          type: type,
          stockName: stockName,
          stockCode: stockCode,
          url: url,
          backendService: _backendService,
        ),
      );
    } else {
      // 没有URL，显示简单解读
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
                SizedBox(height: 8.h),
                Text('$stockName ($stockCode)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
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
                    _generateAiInterpretation(type, title, stockName),
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
  }

  /// 根据公告类型和标题生成简单 AI 解读 - 使用大白话
  String _generateAiInterpretation(String type, String title, String stockName) {
    final lowerTitle = title.toLowerCase();
    final lowerType = type.toLowerCase();

    if (lowerTitle.contains('分红') || lowerTitle.contains('利润分配') || lowerTitle.contains('派息')) {
      return '🎉 好消息！$stockName要给大家发红包了！\n\n'
          '这说明公司赚钱了，愿意把利润分给股东。就像你投资了一家生意好的店，老板给你分红一样。\n\n'
          '💡 投资提示：分红多的公司通常比较稳健，适合长期持有。记得关注什么时候能拿到这笔钱（除权除息日）。';
    } else if (lowerTitle.contains('增持') || lowerTitle.contains('回购')) {
      return '👍 内部人士在"抄底"！\n\n'
          '公司的大股东或高管正在买入自家股票，这就像饭店老板自己掏钱买自家店的股份。说明他们对公司未来很有信心！\n\n'
          '💡 投资提示：这是积极信号，但要看买入金额大不大。如果只是象征性买一点，意义就不大。';
    } else if (lowerTitle.contains('减持')) {
      return '⚠️ 有人在"套现"了\n\n'
          '公司股东在卖股票换现金。如果是高管减持，可能觉得现在股价偏高；如果是投资机构减持，可能只是正常退出。\n\n'
          '💡 投资提示：不要慌！关键看减持比例。如果卖得不多（比如不到1%），影响有限。但如果大股东大量抛售，就要小心了。';
    } else if (lowerTitle.contains('业绩') || lowerTitle.contains('预告') || lowerTitle.contains('快报')) {
      return '📊 $stockName的"成绩单"来了\n\n'
          '公司发布了业绩预报，告诉你这段时间赚了多少钱、生意好不好。这是判断公司好坏的重要依据。\n\n'
          '💡 投资提示：不仅要看赚了多少，还要看和去年比是增长还是下滑。和行业其他公司比怎么样？';
    } else if (lowerTitle.contains('合同') || lowerTitle.contains('中标') || lowerTitle.contains('签约')) {
      return '🎊 $stockName拿下大单子！\n\n'
          '公司签了大合同或中标了项目，就像你开的店接了一个大订单，未来收入有保障了。\n\n'
          '💡 投资提示：合同金额越大越好，但也要看能不能顺利执行。有些合同看着很大，实际回款很慢。';
    } else if (lowerTitle.contains('担保') || lowerTitle.contains('质押')) {
      return '⚡ 注意！公司在"借钱"或"抵押"\n\n'
          '公司可能用资产做抵押借钱，或者为别人做担保。这就像你拿房子抵押贷款，或者帮朋友担保贷款。\n\n'
          '💡 投资提示：适度借贷是正常的，但如果担保金额太大，一旦对方还不上钱，公司就要替还，风险很大！';
    } else if (lowerTitle.contains('处罚') || lowerTitle.contains('违规') || lowerTitle.contains('监管')) {
      return '🚨 红灯警告！公司被"点名批评"了\n\n'
          '公司因为某些违规行为被监管部门处罚了，比如财务造假、信息披露不及时等。这是负面消息！\n\n'
          '💡 投资提示：要看处罚严重程度。如果是小违规，影响不大；如果是财务造假这种大问题，建议远离！';
    } else if (lowerTitle.contains('股东大会') || lowerTitle.contains('临时')) {
      return '🏛️ 公司要开"股东大会"了\n\n'
          '就像公司的"全体会议"，要讨论一些重要事项，比如选新董事、决定是否收购其他公司、要不要增发股票等。\n\n'
          '💡 投资提示：关注会议要表决什么议案。特别是涉及融资、并购、高管变动的事项，可能影响股价。';
    } else if (lowerTitle.contains('年报') || lowerTitle.contains('半年报') || lowerTitle.contains('季报') || lowerTitle.contains('报告')) {
      return '📈 $stockName的"体检报告"出炉\n\n'
          '这是公司最全面的财务报告，告诉你：赚了多少钱？花了多少钱？欠了多少钱？手里还有多少钱？\n\n'
          '💡 投资提示：重点关注三个数字：\n'
          '1️⃣ 营业收入 - 生意做得多大\n'
          '2️⃣ 净利润 - 实际赚了多少钱\n'
          '3️⃣ 现金流 - 手里有没有真金白银';
    } else {
      return '📋 这是一则$type公告\n\n'
          '公告标题：$title\n\n'
          '💡 投资提示：建议仔细阅读公告全文，了解具体内容和可能对$stockName股价的影响。'
          '如果看不懂专业术语，可以搜索相关解释或咨询专业人士。';
    }
  }
}

/// 个股公告底部弹窗组件
class _StockAnnouncementSheet extends StatefulWidget {
  final String code;
  final String name;
  final BackendService backendService;

  const _StockAnnouncementSheet({
    required this.code,
    required this.name,
    required this.backendService,
  });

  @override
  State<_StockAnnouncementSheet> createState() => _StockAnnouncementSheetState();
}

class _StockAnnouncementSheetState extends State<_StockAnnouncementSheet> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _news = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 并行获取公告和新闻
      final results = await Future.wait([
        widget.backendService.getTodayAnnouncements(keyword: widget.name),
        widget.backendService.getStockNews(widget.code),
      ]);

      setState(() {
        _announcements = results[0];
        _news = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载数据失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
                          widget.name,
                          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.code,
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

              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48.sp, color: Colors.grey),
                        SizedBox(height: 8.h),
                        Text(_error!, style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8.h),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // 公告标签
                Row(
                  children: [
                    Icon(Icons.article, size: 18.sp, color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: 4.w),
                    Text(
                      '相关公告 (${_announcements.length})',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // 公告列表
                      if (_announcements.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text('暂无相关公告', style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._announcements.map((a) => Card(
                          margin: EdgeInsets.only(bottom: 8.h),
                          child: ListTile(
                            title: Text(
                              a['title'] ?? '',
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(2.r),
                                  ),
                                  child: Text(
                                    a['type'] ?? '公告',
                                    style: TextStyle(fontSize: 10.sp, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(a['date'] ?? '', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                              ],
                            ),
                            dense: true,
                            onTap: () {
                              // 显示公告详情
                              Navigator.pop(context); // 先关闭当前sheet
                              _showAnnouncementDetail(
                                title: a['title'] ?? '',
                                date: a['date'] ?? '',
                                type: a['type'] ?? '公告',
                                stockName: widget.name,
                                stockCode: widget.code,
                                url: a['url'] ?? '',
                              );
                            },
                          ),
                        )),

                      // 新闻标签
                      if (_news.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Icon(Icons.newspaper, size: 18.sp, color: Colors.orange),
                            SizedBox(width: 4.w),
                            Text(
                              '相关新闻 (${_news.length})',
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        ..._news.map((n) => Card(
                          margin: EdgeInsets.only(bottom: 8.h),
                          child: ListTile(
                            title: Text(
                              n['title'] ?? '',
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    n['source'] ?? '',
                                    style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  n['time'] ?? '',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                                ),
                              ],
                            ),
                            dense: true,
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 公告详情底部弹窗 - 显示原文深度解读
class _AnnouncementDetailSheet extends StatefulWidget {
  final String title;
  final String date;
  final String type;
  final String stockName;
  final String stockCode;
  final String url;
  final BackendService backendService;

  const _AnnouncementDetailSheet({
    required this.title,
    required this.date,
    required this.type,
    required this.stockName,
    required this.stockCode,
    required this.url,
    required this.backendService,
  });

  @override
  State<_AnnouncementDetailSheet> createState() => _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState extends State<_AnnouncementDetailSheet> {
  Map<String, dynamic>? _detailData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final result = await widget.backendService.getAnnouncementDetail(
        url: widget.url,
        title: widget.title,
        stockName: widget.stockName,
      );

      setState(() {
        _detailData = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载公告详情失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '公告详情',
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${widget.stockName} (${widget.stockCode})',
                          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
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
              Divider(height: 24.h),

              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48.sp, color: Colors.grey),
                        SizedBox(height: 8.h),
                        Text(_error!, style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 8.h),
                        ElevatedButton(
                          onPressed: _loadDetail,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // 公告基本信息
                      Row(
                        children: [
                          Chip(
                            label: Text(widget.type),
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          ),
                          SizedBox(width: 8.w),
                          Icon(Icons.calendar_today, size: 14.sp, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            widget.date,
                            style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // 公告标题
                      Text(
                        widget.title,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 16.h),

                      // 深度解读
                      if (_detailData != null && _detailData!['interpretation'] != null) ...[
                        _buildInterpretationSection(_detailData!['interpretation']),
                        SizedBox(height: 16.h),
                      ],

                      // 原文预览
                      if (_detailData != null && _detailData!['content_preview'] != null) ...[
                        _buildContentPreview(_detailData!['content_preview']),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInterpretationSection(Map<String, dynamic> interpretation) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'AI深度解读',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // 摘要
          if (interpretation['summary'] != null) ...[
            Text(
              '📝 摘要',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4.h),
            Text(
              interpretation['summary'],
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
            ),
            SizedBox(height: 12.h),
          ],

          // 关键要点
          if (interpretation['key_points'] != null && (interpretation['key_points'] as List).isNotEmpty) ...[
            Text(
              '🔑 关键要点',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4.h),
            ...((interpretation['key_points'] as List).map((point) => Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(fontSize: 13.sp)),
                  Expanded(
                    child: Text(
                      point.toString(),
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ))),
            SizedBox(height: 12.h),
          ],

          // 影响分析
          if (interpretation['impact'] != null) ...[
            Text(
              '📊 影响分析',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4.h),
            Text(
              interpretation['impact'],
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
            ),
            SizedBox(height: 12.h),
          ],

          // 投资建议
          if (interpretation['suggestion'] != null) ...[
            Text(
              '💡 投资建议',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4.h),
            Text(
              interpretation['suggestion'],
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentPreview(String content) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.grey[600], size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                '原文预览',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            content,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700], height: 1.5),
          ),
          if (content.length >= 500) ...[
            SizedBox(height: 8.h),
            Text(
              '... (内容已截断)',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
