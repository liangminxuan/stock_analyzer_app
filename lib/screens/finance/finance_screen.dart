import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/api_service.dart';
import '../../services/backend_service.dart';

/// 财报中心页面 - 从后端获取实时财报数据
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StockApiService _apiService = StockApiService();
  final BackendService _backendService = BackendService();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

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

          // 搜索结果或提示
          Expanded(
            child: _hasSearched ? _buildSearchResults() : _buildPlaceholder(),
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
                hintText: '搜索股票代码查看财报',
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

  /// 未搜索时的占位页面
  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80.sp, color: Colors.grey.withOpacity(0.5)),
          SizedBox(height: 16.h),
          Text(
            '搜索股票查看财报数据',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey),
          ),
          SizedBox(height: 8.h),
          Text(
            '输入股票名称或代码，获取最新财务报表',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
          ),
          SizedBox(height: 24.h),
          // 热门股票快捷入口
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildQuickChip('贵州茅台', '600519'),
              _buildQuickChip('宁德时代', '300750'),
              _buildQuickChip('中国平安', '601318'),
              _buildQuickChip('比亚迪', '002594'),
              _buildQuickChip('招商银行', '600036'),
              _buildQuickChip('腾讯控股', '00700'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String name, String code) {
    return ActionChip(
      label: Text('$name ($code)'),
      onPressed: () {
        _searchController.text = code;
        _searchStock();
      },
    );
  }

  /// 构建搜索结果
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
            _showStockFinance(stock);
          },
        );
      },
    );
  }

  /// 显示股票财报（从后端获取）
  void _showStockFinance(Map<String, dynamic> stock) {
    final code = stock['code']?.toString() ?? '';
    final name = stock['name']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _StockFinanceSheet(
        code: code,
        name: name,
        backendService: _backendService,
      ),
    );
  }
}

/// 个股财报底部弹窗组件
class _StockFinanceSheet extends StatefulWidget {
  final String code;
  final String name;
  final BackendService backendService;

  const _StockFinanceSheet({
    required this.code,
    required this.name,
    required this.backendService,
  });

  @override
  State<_StockFinanceSheet> createState() => _StockFinanceSheetState();
}

class _StockFinanceSheetState extends State<_StockFinanceSheet> {
  List<Map<String, dynamic>> _financialData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final result = await widget.backendService.getStockFinancial(widget.code);
      setState(() {
        _financialData = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载财报数据失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                          widget.name,
                          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.code} · 财务数据',
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
              else if (_financialData.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 48.sp, color: Colors.grey),
                        SizedBox(height: 8.h),
                        Text('暂无财报数据', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else ...[
                // 最新一期财务指标卡片
                _buildLatestMetrics(),
                SizedBox(height: 16.h),

                // 历史财报列表
                Row(
                  children: [
                    Icon(Icons.history, size: 18.sp, color: Theme.of(context).colorScheme.primary),
                    SizedBox(width: 4.w),
                    Text(
                      '历史财报',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: _financialData.map((item) {
                      return _buildReportCard(item);
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 构建最新一期财务指标
  Widget _buildLatestMetrics() {
    if (_financialData.isEmpty) return const SizedBox.shrink();

    final latest = _financialData.first;
    final reportDate = latest['report_date'] ?? '最新报告期';

    // 提取关键指标
    final metrics = <String, String>{};
    latest.forEach((key, value) {
      if (key != 'report_date' && value != null && value.toString().isNotEmpty) {
        metrics[key] = value.toString();
      }
    });

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, size: 16.sp, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 4.w),
              Text(
                '最新报告期: $reportDate',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // 显示关键指标（最多8个）
          ...metrics.entries.take(8).map((entry) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    entry.value,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建历史财报卡片
  Widget _buildReportCard(Map<String, dynamic> item) {
    final reportDate = item['report_date'] ?? '';

    // 提取几个关键指标用于摘要
    final revenue = item['营业总收入'] ?? '';
    final netProfit = item['净利润'] ?? '';
    final eps = item['基本每股收益'] ?? '';
    final roe = item['净资产收益率'] ?? '';

    String summary = '';
    if (revenue.isNotEmpty) summary += '营收: $revenue  ';
    if (netProfit.isNotEmpty) summary += '净利润: $netProfit';
    if (summary.isEmpty) {
      // 如果没有标准字段，取前几个非空字段
      final otherFields = item.entries
          .where((e) => e.key != 'report_date' && e.value != null && e.value.toString().isNotEmpty)
          .take(2)
          .map((e) => '${e.key}: ${e.value}')
          .join('  ');
      summary = otherFields;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        title: Row(
          children: [
            Text(
              reportDate,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            if (eps.isNotEmpty) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'EPS: $eps',
                  style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(
                  summary,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (roe.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  'ROE: $roe',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                ),
              ),
          ],
        ),
        dense: true,
        onTap: () {
          _showReportDetail(item);
        },
      ),
    );
  }

  /// 显示财报详情
  void _showReportDetail(Map<String, dynamic> item) {
    final reportDate = item['report_date'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$reportDate 财报详情', style: TextStyle(fontSize: 16.sp)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.name} (${widget.code})', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),
              Text('主要财务数据', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
              SizedBox(height: 8.h),
              // 显示所有指标
              ...item.entries.where((e) => e.key != 'report_date' && e.value != null && e.value.toString().isNotEmpty).map((entry) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Flexible(
                        child: Text(
                          entry.value.toString(),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              SizedBox(height: 16.h),
              Text('AI解读', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _generateFinanceInterpretation(item, widget.name),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13.sp),
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

  /// 根据财报数据生成大白话 AI 解读
  String _generateFinanceInterpretation(Map<String, dynamic> item, String stockName) {
    final revenue = item['营业总收入']?.toString() ?? '';
    final netProfit = item['净利润']?.toString() ?? '';
    final eps = item['基本每股收益']?.toString() ?? '';
    final roe = item['净资产收益率']?.toString() ?? '';
    final grossMargin = item['销售毛利率']?.toString() ?? '';
    final reportDate = item['report_date']?.toString() ?? '';

    final buffer = StringBuffer();
    buffer.writeln('📊 $stockName $reportDate 财报解读\n');

    // 营收解读
    if (revenue.isNotEmpty) {
      buffer.writeln('💰 生意做得多大？');
      buffer.writeln('营业收入：$revenue');
      buffer.writeln('→ 这是公司卖产品/服务收到的总钱数\n');
    }

    // 净利润解读
    if (netProfit.isNotEmpty) {
      buffer.writeln('💵 实际赚了多少钱？');
      buffer.writeln('净利润：$netProfit');
      buffer.writeln('→ 扣掉所有成本、税费后真正赚到手的钱\n');
    }

    // EPS解读
    if (eps.isNotEmpty) {
      buffer.writeln('📈 每股能赚多少？');
      buffer.writeln('每股收益：$eps');
      buffer.writeln('→ 每持有一股股票，公司帮你赚了这么多钱\n');
    }

    // ROE解读 - 大白话
    if (roe.isNotEmpty) {
      final roeValue = double.tryParse(roe.replaceAll(RegExp(r'[^\d.\-]'), ''));
      buffer.writeln('🏆 赚钱能力强不强？');
      buffer.writeln('ROE（净资产收益率）：$roe');
      if (roeValue != null) {
        if (roeValue > 20) {
          buffer.writeln('→ 🌟 超强！公司用股东的钱很能赚钱，巴菲特最喜欢的类型！');
        } else if (roeValue > 15) {
          buffer.writeln('→ 👍 很不错！公司赚钱能力优秀，值得长期关注。');
        } else if (roeValue > 10) {
          buffer.writeln('→ 😊 还可以！赚钱能力中等偏上，算是个好学生。');
        } else if (roeValue > 5) {
          buffer.writeln('→ 🤔 一般般。赚钱能力普通，可能行业竞争激烈。');
        } else {
          buffer.writeln('→ ⚠️ 较差。公司赚钱能力弱，投资要谨慎！');
        }
      }
      buffer.writeln('');
    }

    // 毛利率解读 - 大白话
    if (grossMargin.isNotEmpty) {
      final marginValue = double.tryParse(grossMargin.replaceAll(RegExp(r'[^\d.\-]'), ''));
      buffer.writeln('🎯 产品竞争力如何？');
      buffer.writeln('毛利率：$grossMargin');
      if (marginValue != null) {
        if (marginValue > 60) {
          buffer.writeln('→ 💎 超高！产品有很强的定价权，可能是独家技术或品牌。');
        } else if (marginValue > 40) {
          buffer.writeln('→ ✅ 很好！产品利润空间大，竞争力强。');
        } else if (marginValue > 20) {
          buffer.writeln('→ 👌 正常。大多数行业都在这个水平。');
        } else {
          buffer.writeln('→ 📉 偏低。行业可能很卷，或者公司没有定价权。');
        }
      }
      buffer.writeln('');
    }

    // 总结建议
    buffer.writeln('💡 投资小建议：');
    buffer.writeln('1. 不仅要看这一期财报，还要看连续几期的趋势');
    buffer.writeln('2. 和同行业的其他公司对比，才知道好坏');
    buffer.writeln('3. 好财报不等于好股价，还要看市场情绪和估值');

    return buffer.toString();
  }
}
