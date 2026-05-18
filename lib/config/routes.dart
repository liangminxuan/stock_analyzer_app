import 'package:flutter/material.dart';
import '../screens/main/main_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/market/market_screen.dart';
import '../screens/market/stock_detail_screen.dart';
import '../screens/market/search_screen.dart';
import '../screens/finance/finance_screen.dart';
import '../screens/news/news_screen.dart';
import '../screens/discovery/discovery_screen.dart';

/// 路由配置
class Routes {
  static const String home = '/';
  static const String main = '/main';
  static const String market = '/market';
  static const String stockDetail = '/stock_detail';
  static const String search = '/search';
  static const String finance = '/finance';
  static const String news = '/news';
  static const String discovery = '/discovery';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );

      case main:
        return MaterialPageRoute(
          builder: (_) => const MainScreen(),
        );

      case market:
        return MaterialPageRoute(
          builder: (_) => const MarketScreen(),
        );

      case stockDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => StockDetailScreen(
            stockCode: args?['code'] ?? '',
            stockName: args?['name'] ?? '',
          ),
        );

      case search:
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(),
        );

      case finance:
        return MaterialPageRoute(
          builder: (_) => const FinanceScreen(),
        );

      case news:
        return MaterialPageRoute(
          builder: (_) => const NewsScreen(),
        );

      case discovery:
        return MaterialPageRoute(
          builder: (_) => const DiscoveryScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('未找到页面: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
