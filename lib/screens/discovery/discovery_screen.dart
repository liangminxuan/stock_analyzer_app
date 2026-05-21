import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/routes.dart';
import '../../services/discovery_service.dart';

/// 选股页面 - 智能选股与股票筛选
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final DiscoveryService _discoveryService = DiscoveryService();

  bool _isLoading = false;
  String _selectedStrategy = 'comprehensive';

  // 筛选条件
  double _peMin = 0;
  double _peMax = 50;
  double _pbMax = 5;
  double _roeMin = 8;
  double _marketCapMin = 50;
  double _turnoverMin = 2;

  // 选股结果
  List<Map<String, dynamic>> _screenResults = [];
  int _totalResults = 0;
  bool _showResults = false;

  final strategies = [
    {'id': 'comprehensive', 'name': '综合选股', 'desc': '多维度均衡配置', 'icon': Icons.auto_awesome},
    {'id': 'value', 'name': '价值优选', 'desc': '低估值高分红', 'icon': Icons.savings},
    {'id': 'growth', 'name': '成长先锋', 'desc': '高成长潜力股', 'icon': Icons.trending_up},
    {'id': 'tech', 'name': '技术突破', 'desc': '趋势强势突破', 'icon': Icons.candlestick_chart},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '智能选股',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_showResults)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                setState(() {
                  _showResults = false;
                });
              },
            ),
        ],
      ),
      body: _showResults ? _buildResultsView() : _buildFilterView(),
    );
  }

  /// 筛选条件视图
  Widget _buildFilterView() {
    return SingleChildScrollView(
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

          // 筛选条件设置
          _buildFilterSettings(),

          SizedBox(height: 24.h),

          // 开始选股按钮
          _buildStartButton(),

          SizedBox(height: 24.h),

          // 热门策略说明
          _buildStrategySection(),
        ],
      ),
    );
  }

  /// 结果展示视图
  Widget _buildResultsView() {
    return Column(
      children: [
        // 结果头部
        Container(
          padding: EdgeInsets.all(16.w),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '筛选结果',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '共找到 $_totalResults 只股票',
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showResults = false;
                  });
                },
                child: const Text('重新筛选'),
              ),
            ],
          ),
        ),

        // 股票列表
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _screenResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64.sp, color: Colors.grey),
                          SizedBox(height: 16.h),
                          Text('未找到符合条件的股票', style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 8.h),
                          Text('请放宽筛选条件后重试', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: _screenResults.length,
                      itemBuilder: (context, index) {
                        final stock = _screenResults[index];
                        return _buildStockCard(stock, index + 1);
                      },
                    ),
        ),
      ],
    );
  }

  /// 构建AI选股卡片
  Widget _buildAIPickerCard() {
    final strategy = strategies.firstWhere((s) => s['id'] == _selectedStrategy);

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
                  strategy['icon'] as IconData,
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
                      strategy['name'] as String,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      strategy['desc'] as String,
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
        ],
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
                    // 根据策略自动调整筛选条件
                    _applyStrategyFilters(strategy['id'] as String);
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

  /// 根据策略自动调整筛选条件
  void _applyStrategyFilters(String strategy) {
    switch (strategy) {
      case 'value':
        _peMin = 0;
        _peMax = 20;
        _pbMax = 3;
        _roeMin = 10;
        _marketCapMin = 100;
        _turnoverMin = 1;
        break;
      case 'growth':
        _peMin = 10;
        _peMax = 80;
        _pbMax = 8;
        _roeMin = 5;
        _marketCapMin = 20;
        _turnoverMin = 3;
        break;
      case 'tech':
        _peMin = 0;
        _peMax = 100;
        _pbMax = 10;
        _roeMin = 0;
        _marketCapMin = 50;
        _turnoverMin = 5;
        break;
      default: // comprehensive
        _peMin = 5;
        _peMax = 50;
        _pbMax = 5;
        _roeMin = 8;
        _marketCapMin = 50;
        _turnoverMin = 2;
    }
  }

  /// 构建筛选条件设置
  Widget _buildFilterSettings() {
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
        SizedBox(height: 16.h),

        // 市盈率范围
        _buildRangeSlider(
          label: '市盈率 (PE)',
          min: 0,
          max: 100,
          start: _peMin,
          end: _peMax,
          onChanged: (start, end) {
            setState(() {
              _peMin = start;
              _peMax = end;
            });
          },
        ),

        SizedBox(height: 16.h),

        // 市净率上限
        _buildSlider(
          label: '市净率 (PB) < ${_pbMax.toStringAsFixed(1)}',
          value: _pbMax,
          min: 1,
          max: 10,
          onChanged: (value) {
            setState(() {
              _pbMax = value;
            });
          },
        ),

        SizedBox(height: 16.h),

        // ROE下限
        _buildSlider(
          label: '净资产收益率 (ROE) > ${_roeMin.toStringAsFixed(1)}%',
          value: _roeMin,
          min: 0,
          max: 30,
          onChanged: (value) {
            setState(() {
              _roeMin = value;
            });
          },
        ),

        SizedBox(height: 16.h),

        // 市值下限
        _buildSlider(
          label: '流通市值 > ${_marketCapMin.toStringAsFixed(0)}亿',
          value: _marketCapMin,
          min: 10,
          max: 500,
          divisions: 49,
          onChanged: (value) {
            setState(() {
              _marketCapMin = value;
            });
          },
        ),

        SizedBox(height: 16.h),

        // 换手率下限
        _buildSlider(
          label: '换手率 > ${_turnoverMin.toStringAsFixed(1)}%',
          value: _turnoverMin,
          min: 0,
          max: 10,
          onChanged: (value) {
            setState(() {
              _turnoverMin = value;
            });
          },
        ),
      ],
    );
  }

  /// 构建范围滑块
  Widget _buildRangeSlider({
    required String label,
    required double min,
    required double max,
    required double start,
    required double end,
    required Function(double, double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14.sp)),
            Text(
              '${start.toStringAsFixed(0)} - ${end.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 14.sp, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues(start, end),
          min: min,
          max: max,
          divisions: 20,
          labels: RangeLabels(
            start.toStringAsFixed(0),
            end.toStringAsFixed(0),
          ),
          onChanged: (values) {
            onChanged(values.start, values.end);
          },
        ),
      ],
    );
  }

  /// 构建滑块
  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14.sp)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions ?? (max - min).toInt() * 2,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }

  /// 构建开始按钮
  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _startStockSelection,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 48.h),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      child: _isLoading
          ? SizedBox(
              width: 20.w,
              height: 20.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('开始选股', style: TextStyle(fontSize: 16)),
    );
  }

  /// 开始选股
  Future<void> _startStockSelection() async {
    setState(() {
      _isLoading = true;
      _showResults = true;
    });

    try {
      // 先尝试使用策略推荐API
      final result = await _discoveryService.recommendStocks(
        strategy: _selectedStrategy,
        count: 20,
      );

      if (result['success'] == true && (result['data'] as List).isNotEmpty) {
        setState(() {
          _screenResults = List<Map<String, dynamic>>.from(result['data']);
          _totalResults = result['count'] ?? _screenResults.length;
        });
      } else {
        // 如果推荐API没有结果，使用筛选API
        final screenResult = await _discoveryService.screenStocks(
          peMin: _peMin > 0 ? _peMin : null,
          peMax: _peMax < 100 ? _peMax : null,
          pbMax: _pbMax < 10 ? _pbMax : null,
          roeMin: _roeMin > 0 ? _roeMin : null,
          marketCapMin: _marketCapMin > 10 ? _marketCapMin : null,
          turnoverMin: _turnoverMin > 0 ? _turnoverMin : null,
          size: 20,
        );

        setState(() {
          _screenResults = List<Map<String, dynamic>>.from(screenResult['data'] ?? []);
          _totalResults = screenResult['total'] ?? _screenResults.length;
        });
      }
    } catch (e) {
      print('选股失败: $e');
      setState(() {
        _screenResults = [];
        _totalResults = 0;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 构建股票卡片
  Widget _buildStockCard(Map<String, dynamic> stock, int rank) {
    final changePercent = (stock['change_percent'] ?? 0) as double;
    final isPositive = changePercent >= 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rank <= 3
              ? Colors.orange.withOpacity(0.2)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Text(
            '$rank',
            style: TextStyle(
              color: rank <= 3 ? Colors.orange : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                stock['name'] ?? '',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isPositive ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isPositive ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text(
              '${stock['code']} · PE:${stock['pe']?.toStringAsFixed(1) ?? '-'} · PB:${stock['pb']?.toStringAsFixed(1) ?? '-'}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
            if (stock['reason'] != null) ...[
              SizedBox(height: 4.h),
              Text(
                stock['reason'],
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final code = stock['code']?.toString() ?? '';
          Navigator.pushNamed(
            context,
            Routes.stockDetail,
            arguments: {
              'code': '${code.startsWith('6') ? 'sh' : 'sz'}$code',
              'name': stock['name'] ?? '',
            },
          );
        },
      ),
    );
  }

  /// 构建热门策略说明
  Widget _buildStrategySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '策略说明',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16.h),
        _buildStrategyInfoCard(
          '价值投资',
          '寻找低PE(<20)、低PB(<3)、高ROE(>10%)的大盘股，适合稳健型投资者',
          Icons.savings,
        ),
        SizedBox(height: 12.h),
        _buildStrategyInfoCard(
          '成长投资',
          '关注中等估值、高活跃度、中小市值股票，适合激进型投资者',
          Icons.trending_up,
        ),
        SizedBox(height: 12.h),
        _buildStrategyInfoCard(
          '技术突破',
          '筛选近期强势、高换手率、量价配合的股票，适合短线交易者',
          Icons.candlestick_chart,
        ),
      ],
    );
  }

  Widget _buildStrategyInfoCard(String name, String desc, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4.h),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
