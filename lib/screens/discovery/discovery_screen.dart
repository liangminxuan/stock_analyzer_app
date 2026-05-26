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
  String _loadingMessage = ''; // 加载状态提示

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

          SizedBox(height: 16.h),

          // AI 对冲基金分析入口
          _buildAIHedgeFundCard(),

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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: 16.h),
                      Text(
                        _loadingMessage.isNotEmpty ? _loadingMessage : '加载中...',
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                      ),
                      if (_loadingMessage.contains('数据'))
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Text(
                            '首次加载需要获取A股全量数据，请耐心等待',
                            style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                          ),
                        ),
                    ],
                  ),
                )
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

  /// 构建AI对冲基金分析入口卡片
  Widget _buildAIHedgeFundCard() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, Routes.aiAnalysis);
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFFE2B714).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: const Color(0xFFE2B714).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.psychology,
                color: const Color(0xFFE2B714),
                size: 28.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'AI 对冲基金分析',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2B714).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          '量化',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: const Color(0xFFE2B714),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '趋势·均值回归·动量·波动率·统计套利',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.5),
              size: 24.sp,
            ),
          ],
        ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '筛选条件',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 指标说明按钮
            TextButton.icon(
              onPressed: _showIndicatorHelp,
              icon: Icon(Icons.help_outline, size: 18.sp),
              label: Text('指标说明', style: TextStyle(fontSize: 13.sp)),
            ),
          ],
        ),
        SizedBox(height: 16.h),

        // 市盈率范围
        _buildRangeSliderWithHelp(
          label: '市盈率 (PE)',
          helpText: 'PE = 股价 ÷ 每股收益。衡量股票估值水平，数值越低表示股票越"便宜"。',
          helpDetail: '• PE < 15：低估值，适合价值投资\n• PE 15-30：合理估值\n• PE > 30：高估值，需关注成长性',
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
        _buildSliderWithHelp(
          label: '市净率 (PB)',
          helpText: 'PB = 股价 ÷ 每股净资产。衡量股价相对账面价值的倍数。',
          helpDetail: '• PB < 1：股价低于净资产，可能被低估\n• PB 1-3：合理区间\n• PB > 5：溢价较高，需谨慎',
          value: _pbMax,
          min: 1,
          max: 10,
          displayValue: _pbMax.toStringAsFixed(1),
          onChanged: (value) {
            setState(() {
              _pbMax = value;
            });
          },
        ),

        SizedBox(height: 16.h),

        // ROE下限
        _buildSliderWithHelp(
          label: '净资产收益率 (ROE)',
          helpText: 'ROE = 净利润 ÷ 净资产 × 100%。衡量公司用股东资金赚钱的能力。',
          helpDetail: '• ROE > 15%：优秀，巴菲特首选指标\n• ROE 10-15%：良好\n• ROE < 8%：盈利能力较弱',
          value: _roeMin,
          min: 0,
          max: 30,
          displayValue: '${_roeMin.toStringAsFixed(1)}%',
          onChanged: (value) {
            setState(() {
              _roeMin = value;
            });
          },
        ),

        SizedBox(height: 16.h),

        // 市值下限
        _buildSliderWithHelp(
          label: '流通市值',
          helpText: '市值 = 股价 × 流通股本。反映公司规模大小和市场影响力。',
          helpDetail: '• > 500亿：大盘蓝筹，稳定性高\n• 100-500亿：中盘股，成长性较好\n• < 100亿：小盘股，波动较大',
          value: _marketCapMin,
          min: 10,
          max: 500,
          divisions: 49,
          displayValue: '${_marketCapMin.toStringAsFixed(0)}亿',
          onChanged: (value) {
            setState(() {
              _marketCapMin = value;
            });
          },
        ),

        SizedBox(height: 16.h),

        // 换手率下限
        _buildSliderWithHelp(
          label: '换手率',
          helpText: '换手率 = 成交量 ÷ 流通股本 × 100%。反映股票交易活跃程度。',
          helpDetail: '• > 10%：非常活跃，关注度高\n• 3-10%：活跃，流动性好\n• < 3%：较冷清，流动性一般',
          value: _turnoverMin,
          min: 0,
          max: 10,
          displayValue: '${_turnoverMin.toStringAsFixed(1)}%',
          onChanged: (value) {
            setState(() {
              _turnoverMin = value;
            });
          },
        ),
      ],
    );
  }

  /// 显示指标说明弹窗
  void _showIndicatorHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                '技术指标详解',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20.h),
              
              _buildIndicatorDetailCard(
                'PE（市盈率）',
                'Price-to-Earnings Ratio',
                'PE = 股价 ÷ 每股收益(EPS)',
                '衡量投资者为每1元净利润支付的价格，反映股票的估值水平。',
                [
                  'PE < 15：低估值，股价相对便宜，适合价值投资',
                  'PE 15-30：合理估值区间',
                  'PE 30-50：偏高估值，需关注成长性支撑',
                  'PE > 50：高估值，风险较大',
                  '负PE：公司亏损，不适用此指标',
                ],
                Icons.attach_money,
                Colors.blue,
              ),
              
              SizedBox(height: 16.h),
              
              _buildIndicatorDetailCard(
                'PB（市净率）',
                'Price-to-Book Ratio',
                'PB = 股价 ÷ 每股净资产',
                '衡量股价相对于公司账面价值的倍数，常用于判断是否被低估。',
                [
                  'PB < 1：股价低于净资产，可能被低估（需排除财务风险）',
                  'PB 1-2：合理区间',
                  'PB 2-5：有一定溢价',
                  'PB > 5：溢价较高，需关注品牌/技术等无形资产',
                  '重资产行业（银行、钢铁）PB通常较低',
                ],
                Icons.account_balance,
                Colors.green,
              ),
              
              SizedBox(height: 16.h),
              
              _buildIndicatorDetailCard(
                'ROE（净资产收益率）',
                'Return on Equity',
                'ROE = 净利润 ÷ 净资产 × 100%',
                '衡量公司利用股东资金创造利润的能力，巴菲特最看重的指标。',
                [
                  'ROE > 20%：优秀，公司盈利能力强',
                  'ROE 15-20%：良好',
                  'ROE 10-15%：一般',
                  'ROE < 10%：盈利能力较弱',
                  '高ROE + 低PE = 理想投资标的',
                ],
                Icons.trending_up,
                Colors.orange,
              ),
              
              SizedBox(height: 16.h),
              
              _buildIndicatorDetailCard(
                '市值',
                'Market Capitalization',
                '市值 = 股价 × 流通股本',
                '反映公司规模大小，影响流动性和稳定性。',
                [
                  '> 1000亿：超大盘蓝筹，稳定性高，适合稳健投资',
                  '500-1000亿：大盘股，机构关注度高',
                  '100-500亿：中盘股，成长性与稳定性兼顾',
                  '50-100亿：小盘股，弹性大但波动也大',
                  '< 50亿：微盘股，风险较高',
                ],
                Icons.pie_chart,
                Colors.purple,
              ),
              
              SizedBox(height: 16.h),
              
              _buildIndicatorDetailCard(
                '换手率',
                'Turnover Rate',
                '换手率 = 成交量 ÷ 流通股本 × 100%',
                '反映股票交易活跃程度和市场关注度。',
                [
                  '> 20%：极度活跃，可能有重大消息',
                  '10-20%：非常活跃，市场关注度高',
                  '5-10%：活跃，流动性好',
                  '2-5%：正常',
                  '< 2%：较冷清，流动性一般',
                  '新股上市初期换手率通常很高',
                ],
                Icons.swap_horiz,
                Colors.red,
              ),
              
              SizedBox(height: 24.h),
              
              // 使用建议
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text('选股建议', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      '• 价值投资：低PE + 低PB + 高ROE + 大市值\n'
                      '• 成长投资：中等PE + 高ROE + 中小市值\n'
                      '• 技术选股：高换手率 + 量价配合\n'
                      '• 风险控制：避免单一指标极端值',
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey[700], height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建指标详情卡片
  Widget _buildIndicatorDetailCard(
    String name,
    String englishName,
    String formula,
    String description,
    List<String> guidelines,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: color, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    Text(englishName, style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(formula, style: TextStyle(fontSize: 13.sp, fontFamily: 'monospace', color: color)),
          ),
          SizedBox(height: 10.h),
          Text(description, style: TextStyle(fontSize: 13.sp, color: Colors.grey[700])),
          SizedBox(height: 12.h),
          ...guidelines.map((g) => Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: 12.sp, color: color)),
                Expanded(child: Text(g, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// 构建带帮助的范围滑块
  Widget _buildRangeSliderWithHelp({
    required String label,
    required String helpText,
    required String helpDetail,
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
            Expanded(
              child: Row(
                children: [
                  Text(label, style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: () => _showQuickHelp(label, helpText, helpDetail),
                    child: Icon(Icons.info_outline, size: 16.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
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

  /// 构建带帮助的滑块
  Widget _buildSliderWithHelp({
    required String label,
    required String helpText,
    required String helpDetail,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String displayValue,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text('$label < ', style: TextStyle(fontSize: 14.sp)),
                  Text(displayValue, style: TextStyle(fontSize: 14.sp, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: () => _showQuickHelp(label, helpText, helpDetail),
                    child: Icon(Icons.info_outline, size: 16.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  /// 显示快速帮助提示
  void _showQuickHelp(String title, String helpText, String helpDetail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(fontSize: 16.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(helpText, style: TextStyle(fontSize: 13.sp)),
            SizedBox(height: 12.h),
            Text(helpDetail, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
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
      _loadingMessage = '正在检查数据状态...';
    });

    try {
      // 先等待股票数据加载就绪
      final dataReady = await _discoveryService.waitForStockData(
        timeout: const Duration(minutes: 3),
      );

      if (!dataReady) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingMessage = '';
            _screenResults = [];
            _totalResults = 0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('股票数据加载失败，请稍后重试。首次使用需要加载A股全量数据，可能需要1-2分钟。'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      setState(() {
        _loadingMessage = '正在选股分析...';
      });

      // 先尝试使用策略推荐API
      final result = await _discoveryService.recommendStocks(
        strategy: _selectedStrategy,
        count: 20,
      );

      if (result['success'] == true && (result['data'] as List).isNotEmpty) {
        setState(() {
          _screenResults = List<Map<String, dynamic>>.from(result['data']);
          _totalResults = result['count'] ?? _screenResults.length;
          _loadingMessage = '';
        });
      } else {
        // 如果推荐API没有结果，使用筛选API
        setState(() {
          _loadingMessage = '正在筛选股票...';
        });

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
          _loadingMessage = '';
        });
      }
    } catch (e) {
      print('选股失败: $e');
      setState(() {
        _screenResults = [];
        _totalResults = 0;
        _loadingMessage = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选股失败: $e')),
        );
      }
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
          // 后端返回的code已经包含sh/sz前缀
          final fullCode = code.startsWith('sh') || code.startsWith('sz') 
              ? code 
              : '${code.startsWith('6') ? 'sh' : 'sz'}$code';
          Navigator.pushNamed(
            context,
            Routes.stockDetail,
            arguments: {
              'code': fullCode,
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
