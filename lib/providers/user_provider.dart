import 'package:flutter/foundation.dart';
import '../models/stock.dart';

/// 用户状态管理
class UserProvider extends ChangeNotifier {
  // 自选股列表
  final List<StockItem> _watchlist = [];
  List<StockItem> get watchlist => List.unmodifiable(_watchlist);

  // 投资组合
  final List<PortfolioItem> _portfolio = [];
  List<PortfolioItem> get portfolio => List.unmodifiable(_portfolio);

  // 分析历史
  final List<AnalysisHistory> _analysisHistory = [];
  List<AnalysisHistory> get analysisHistory => List.unmodifiable(_analysisHistory);

  /// 添加自选股
  void addToWatchlist(StockItem stock) {
    if (!_watchlist.any((s) => s.code == stock.code)) {
      _watchlist.add(stock);
      notifyListeners();
    }
  }

  /// 移除自选股
  void removeFromWatchlist(String code) {
    _watchlist.removeWhere((s) => s.code == code);
    notifyListeners();
  }

  /// 判断是否已添加
  bool isInWatchlist(String code) {
    return _watchlist.any((s) => s.code == code);
  }

  /// 添加到投资组合
  void addToPortfolio(PortfolioItem item) {
    final existingIndex = _portfolio.indexWhere((p) => p.code == item.code);
    if (existingIndex >= 0) {
      _portfolio[existingIndex] = item;
    } else {
      _portfolio.add(item);
    }
    notifyListeners();
  }

  /// 从投资组合移除
  void removeFromPortfolio(String code) {
    _portfolio.removeWhere((p) => p.code == code);
    notifyListeners();
  }

  /// 添加分析历史
  void addAnalysisHistory(AnalysisHistory history) {
    _analysisHistory.insert(0, history);
    if (_analysisHistory.length > 100) {
      _analysisHistory.removeLast();
    }
    notifyListeners();
  }

  /// 清空分析历史
  void clearAnalysisHistory() {
    _analysisHistory.clear();
    notifyListeners();
  }

  /// 计算组合总市值
  double get totalPortfolioValue {
    return _portfolio.fold(0, (sum, item) => sum + item.currentValue);
  }

  /// 计算组合总成本
  double get totalPortfolioCost {
    return _portfolio.fold(0, (sum, item) => sum + item.totalCost);
  }

  /// 计算组合总盈亏
  double get totalPortfolioProfit {
    return totalPortfolioValue - totalPortfolioCost;
  }

  /// 计算组合收益率
  double get totalPortfolioReturn {
    if (totalPortfolioCost == 0) return 0;
    return (totalPortfolioProfit / totalPortfolioCost) * 100;
  }
}

/// 投资组合项
class PortfolioItem {
  final String code;
  final String name;
  final String market;
  final int shares;           // 持仓数量
  final double avgCost;       // 平均成本
  final double currentPrice;  // 当前价格

  PortfolioItem({
    required this.code,
    required this.name,
    required this.market,
    required this.shares,
    required this.avgCost,
    required this.currentPrice,
  });

  String get fullCode => '$market$code';

  /// 总成本
  double get totalCost => shares * avgCost;

  /// 当前市值
  double get currentValue => shares * currentPrice;

  /// 盈亏金额
  double get profit => currentValue - totalCost;

  /// 盈亏比例
  double get profitPercent => avgCost != 0 ? ((currentPrice - avgCost) / avgCost) * 100 : 0;

  /// 是否盈利
  bool get isProfit => profit > 0;
}

/// 分析历史记录
class AnalysisHistory {
  final String id;
  final String type;          // kline / financial / announcement
  final String code;
  final String name;
  final DateTime time;
  final String summary;       // 分析摘要

  AnalysisHistory({
    required this.id,
    required this.type,
    required this.code,
    required this.name,
    required this.time,
    required this.summary,
  });

  String get typeText {
    switch (type) {
      case 'kline':
        return 'K线分析';
      case 'financial':
        return '财报分析';
      case 'announcement':
        return '公告分析';
      default:
        return '其他分析';
    }
  }
}
