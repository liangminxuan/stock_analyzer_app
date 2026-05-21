import 'dart:convert';
import 'package:dio/dio.dart';

/// 公告服务 - 综合多个数据源获取最新公告
/// 注意：由于公开API限制，目前主要使用财经新闻作为替代
class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

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
      },
    ));
    _initialized = true;
  }

  /// 获取最新财经资讯（新浪财经）
  Future<List<Map<String, dynamic>>> getLatestFinanceNews({int page = 1, int num = 20}) async {
    try {
      final url = 'https://feed.mix.sina.com.cn/api/roll/get?pageid=153&lid=2516&k=&num=$num&page=$page&r=${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await _dio.get(url);
      final data = response.data;
      
      if (data['result'] != null && data['result']['data'] != null) {
        final items = data['result']['data'] as List;
        return items.map((item) => {
          'title': item['title'] ?? '',
          'url': item['url'] ?? '',
          'time': _formatTime(item['ctime']),
          'source': item['media_name'] ?? '新浪财经',
          'type': '财经新闻',
        }).toList();
      }
      return [];
    } catch (e) {
      print('[AnnouncementService] 获取新闻失败: $e');
      return [];
    }
  }

  /// 获取个股相关资讯
  Future<List<Map<String, dynamic>>> getStockAnnouncements(String stockCode, String stockName) async {
    List<Map<String, dynamic>> results = [];
    
    // 1. 尝试获取个股新闻
    try {
      final stockNews = await _getStockNewsFromSina(stockName);
      results.addAll(stockNews);
    } catch (e) {
      print('[AnnouncementService] 获取个股新闻失败: $e');
    }
    
    // 2. 添加最新财经新闻
    try {
      final latestNews = await getLatestFinanceNews(num: 10);
      // 过滤与股票相关的
      final relatedNews = latestNews.where((news) {
        final title = news['title'].toString().toLowerCase();
        final name = stockName.toLowerCase();
        final code = stockCode.toLowerCase();
        return title.contains(name) || title.contains(code);
      }).toList();
      results.addAll(relatedNews);
    } catch (e) {
      print('[AnnouncementService] 获取相关新闻失败: $e');
    }
    
    // 按时间排序
    results.sort((a, b) => (b['time'] ?? '').compareTo(a['time'] ?? ''));
    return results.take(20).toList();
  }

  /// 从新浪财经获取个股新闻
  Future<List<Map<String, dynamic>>> _getStockNewsFromSina(String stockName) async {
    try {
      // 新浪财经个股新闻
      final url = 'https://search.sina.com.cn/?q=${Uri.encodeComponent(stockName)}&c=news&from=channel&ie=utf-8';
      
      final response = await _dio.get(url);
      final html = response.data.toString();
      
      // 简单解析HTML提取新闻
      final List<Map<String, dynamic>> news = [];
      final regex = RegExp(r'<a[^>]*href="([^"]*sina\.com\.cn[^"]*)"[^>]*>([^<]*)</a>');
      
      for (final match in regex.allMatches(html)) {
        final url = match.group(1);
        final title = match.group(2)?.trim();
        if (url != null && title != null && title.isNotEmpty && title.length > 10) {
          news.add({
            'title': title,
            'url': url,
            'time': DateTime.now().toString(),
            'source': '新浪财经',
            'type': '个股新闻',
          });
        }
      }
      
      return news.take(10).toList();
    } catch (e) {
      print('[AnnouncementService] 新浪个股新闻失败: $e');
      return [];
    }
  }

  /// 格式化时间
  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final seconds = int.parse(timestamp.toString());
      final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  /// 获取模拟的公告数据（用于展示）
  List<Map<String, dynamic>> getMockAnnouncements(String stockName) {
    final now = DateTime.now();
    return [
      {
        'title': '$stockName 2025年第一季度报告',
        'time': '${now.year}-${now.month.toString().padLeft(2, '0')}-15',
        'source': '公司公告',
        'type': '定期报告',
      },
      {
        'title': '$stockName 关于召开2024年度股东大会的通知',
        'time': '${now.year}-${now.month.toString().padLeft(2, '0')}-10',
        'source': '公司公告',
        'type': '股东大会',
      },
      {
        'title': '$stockName 2024年度业绩快报',
        'time': '${now.year}-${(now.month - 1).toString().padLeft(2, '0')}-28',
        'source': '公司公告',
        'type': '业绩快报',
      },
    ];
  }
}
