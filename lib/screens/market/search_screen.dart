import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';
import '../../models/stock.dart';
import '../../widgets/stock_card.dart';

/// 搜索页面
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final StockApiService _apiService = StockApiService();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.length < 1) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _apiService.searchStocks(keyword);
      setState(() {
        _searchResults = results;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40.h,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: '搜索股票代码/名称',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _hasSearched = false;
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
            ),
            onChanged: (value) {
              setState(() {});
              if (value.length >= 1) {
                _search(value);
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched) {
      return _buildSearchHistory();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            SizedBox(height: 16.h),
            Text(
              '未找到相关股票',
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '请尝试搜索股票代码或名称',
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final stock = _searchResults[index];
        final code = stock['code'] as String;
        final name = stock['name'] as String;
        final market = stock['market'] as String;
        final fullCode = '$market$code';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Text(
              code.isNotEmpty ? code[0] : '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(name),
          subtitle: Text('$code (${market == 'sh' ? '上证' : '深证'})'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pushNamed(
              context,
              Routes.stockDetail,
              arguments: {
                'code': fullCode,
                'name': name,
              },
            );
          },
        );
      },
    );
  }

  /// 构建搜索历史
  Widget _buildSearchHistory() {
    final history = ['000001', '600519', '000858', '300750', '601318'];

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '搜索历史',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: history.map((code) {
              return ActionChip(
                label: Text(code),
                onPressed: () {
                  _searchController.text = code;
                  _search(code);
                },
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),
          Text(
            '热门股票',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildHotStock('贵州茅台', '600519'),
              _buildHotStock('平安银行', '000001'),
              _buildHotStock('五粮液', '000858'),
              _buildHotStock('宁德时代', '300750'),
              _buildHotStock('中国平安', '601318'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotStock(String name, String code) {
    return ActionChip(
      avatar: Icon(Icons.trending_up, size: 16.sp),
      label: Text('$name($code)'),
      onPressed: () {
        _searchController.text = code;
        _search(code);
      },
    );
  }
}
