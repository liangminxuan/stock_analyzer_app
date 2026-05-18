import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../home/home_screen.dart';
import '../market/market_screen.dart';
import '../finance/finance_screen.dart';
import '../discovery/discovery_screen.dart';
import '../profile/profile_screen.dart';

/// 主页面（带底部导航）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const MarketScreen(),
    const FinanceScreen(),
    const DiscoveryScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    '首页',
    '行情',
    '财报',
    '选股',
    '我的',
  ];

  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.trending_up_outlined,
    Icons.insert_chart_outlined,
    Icons.search_outlined,
    Icons.person_outline,
  ];

  final List<IconData> _activeIcons = [
    Icons.home,
    Icons.trending_up,
    Icons.insert_chart,
    Icons.search,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_pages.length, (index) {
                final isActive = _currentIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? _activeIcons[index] : _icons[index],
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          size: 24.sp,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _titles[index],
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
