import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 自选股/持仓等本地数据的存储抽象。
///
/// 抽出接口是为了让 UserProvider 可以在测试里注入内存实现，
/// 而不必依赖真实的 SharedPreferences 插件。
abstract class UserDataStore {
  Future<List<Map<String, dynamic>>> loadWatchlist();
  Future<void> saveWatchlist(List<Map<String, dynamic>> items);
}

/// 基于 SharedPreferences 的实现（App 运行时使用）
class SharedPrefsUserDataStore implements UserDataStore {
  static const String _watchlistKey = 'watchlist_v1';

  @override
  Future<List<Map<String, dynamic>>> loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_watchlistKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      // 本地数据损坏时按空处理，不影响启动
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Future<void> saveWatchlist(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_watchlistKey, json.encode(items));
  }
}

/// 内存实现（测试用）
class InMemoryUserDataStore implements UserDataStore {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> loadWatchlist() async =>
      _items.map((item) => Map<String, dynamic>.from(item)).toList();

  @override
  Future<void> saveWatchlist(List<Map<String, dynamic>> items) async {
    _items = items.map((item) => Map<String, dynamic>.from(item)).toList();
  }
}
