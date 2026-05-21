import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/api_service.dart';
import '../../services/backend_service.dart';

/// 公告解读页面 - 从后端获取实时公告数据
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
          if (url.isNotEmpty)
            TextButton(
              onPressed: () {
                // TODO: 打开网页查看原文
                Navigator.pop(context);
              },
              child: const Text('查看原文'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 根据公告类型和标题生成简单 AI 解读
  String _generateAiInterpretation(String type, String title, String stockName) {
    final lowerTitle = title.toLowerCase();
    final lowerType = type.toLowerCase();

    if (lowerTitle.contains('分红') || lowerTitle.contains('利润分配') || lowerTitle.contains('派息')) {
      return '该公告属于分红派息类，表明$stockName盈利状况良好，有现金回馈股东的能力。建议关注分红比例和除权除息日期。';
    } else if (lowerTitle.contains('增持') || lowerTitle.contains('回购')) {
      return '该公告属于股东增持/回购类，显示大股东或管理层对公司未来发展有信心，属于偏正面信号。建议关注增持金额和后续进展。';
    } else if (lowerTitle.contains('减持')) {
      return '该公告属于股东减持类，需关注减持比例和减持方身份。若为高管减持，可能反映短期估值偏高预期；若为财务投资方正常退出，影响相对有限。';
    } else if (lowerTitle.contains('业绩') || lowerTitle.contains('预告') || lowerTitle.contains('快报')) {
      return '该公告属于业绩披露类，是评估$stockName经营状况的重要依据。建议结合行业趋势和同业对比综合分析。';
    } else if (lowerTitle.contains('合同') || lowerTitle.contains('中标') || lowerTitle.contains('签约')) {
      return '该公告属于重大合同/中标类，显示$stockName获得新业务订单，对未来营收有积极影响。建议关注合同金额和执行周期。';
    } else if (lowerTitle.contains('担保') || lowerTitle.contains('质押')) {
      return '该公告涉及担保/质押事项，需关注担保金额占净资产比例及被担保方资质，评估潜在风险敞口。';
    } else if (lowerTitle.contains('处罚') || lowerTitle.contains('违规') || lowerTitle.contains('监管')) {
      return '该公告涉及监管处罚或违规事项，属于负面信号。建议关注处罚金额、影响范围及公司整改措施。';
    } else if (lowerTitle.contains('股东大会') || lowerTitle.contains('临时')) {
      return '该公告为股东大会通知，建议关注审议议案内容，特别是涉及重大投资、融资、人事变动等事项。';
    } else if (lowerTitle.contains('年报') || lowerTitle.contains('半年报') || lowerTitle.contains('季报') || lowerTitle.contains('报告')) {
      return '该公告为定期报告类，包含$stockName完整的财务数据和经营情况。建议重点关注营收增速、净利润变化、现金流状况等核心指标。';
    } else {
      return '该公告属于$type类别，建议仔细阅读公告原文，关注对$stockName经营和股价可能产生的影响。';
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
