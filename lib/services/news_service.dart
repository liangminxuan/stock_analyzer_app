import 'dart:convert';
import 'package:dio/dio.dart';

/// 财经新闻服务 - 使用新浪财经接口获取最新资讯
class NewsService {
  static final NewsService _instance = NewsService._internal();
  factory NewsService() => _instance;
  NewsService._internal();

  late Dio _dio;
  bool _initialized = false;

  Dio get dio {
    if (!_initialized) init();
    return _dio;
  }

  void init() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://finance.sina.com.cn/',
      },
    ));
    _initialized = true;
  }

  /// 获取最新财经新闻
  Future<List<Map<String, dynamic>>> getLatestNews({int page = 1, int num = 20}) async {
    try {
      // 新浪财经新闻接口
      final url = 'https://feed.mix.sina.com.cn/api/roll/get?pageid=153&lid=2516&k=&num=$num&page=$page&r=${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await _dio.get(url);
      final data = response.data;
      
      if (data['result'] != null && data['result']['data'] != null) {
        final items = data['result']['data'] as List;
        return items.map((item) => {
          'title': item['title'] ?? '',
          'url': item['url'] ?? '',
          'time': item['ctime'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(int.parse(item['ctime']) * 1000).toString()
            : '',
          'source': item['media_name'] ?? '新浪财经',
        }).toList();
      }
      return [];
    } catch (e) {
      print('[NewsService] 获取新闻失败: $e');
      return [];
    }
  }

  /// 获取个股相关新闻（通过搜索）
  Future<List<Map<String, dynamic>>> getStockNews(String stockName, {int num = 10}) async {
    try {
      // 使用新浪财经搜索
      final url = 'https://search.sina.com.cn/?q=${Uri.encodeComponent(stockName)}&c=news&from=channel&ie=utf-8';
      
      final response = await _dio.get(url);
      // 这里需要解析HTML，暂时返回空列表
      // 实际实现需要使用 html 解析库
      return [];
    } catch (e) {
      print('[NewsService] 获取个股新闻失败: $e');
      return [];
    }
  }
}
