/// AI 分析控制器（ChangeNotifier，替代原先的 GetX 实现）
class AIAnalysisController extends ChangeNotifier {
  final BackendService _backendService = BackendService();

  final TextEditingController codeController = TextEditingController();

  String stockCode = '';
  bool isLoading = false;
  String loadingMessage = '正在分析中...';
  bool hasError = false;
  String errorMessage = '';
  Map<String, dynamic>? analysisData;

  /// 开始分析
  Future<void> startAnalysis() async {
    final code = stockCode.trim();
    if (code.length != 6) {
      hasError = true;
      errorMessage = '请输入正确的6位股票代码';
      notifyListeners();
      return;
    }

    isLoading = true;
    hasError = false;
    errorMessage = '';
    loadingMessage = '正在获取 $code 的 AI 分析数据...';
    notifyListeners();

    try {
      final response = await _backendService.dio.get(
        '/api/stock/ai_analysis',
        queryParameters: {'code': code},
      );

      final data = asMap(response.data);
      if (data == null) {
        hasError = true;
        errorMessage = '返回数据格式异常，请稍后重试';
      } else if (data['success'] == true) {
        analysisData = data;
      } else {
        hasError = true;
        errorMessage = (data['error'] as String?) ??
            (data['message'] as String?) ??
            '分析失败，请稍后重试';
      }
    } catch (e) {
      logDebug('[AIAnalysis] 分析失败: $e');
      hasError = true;
      errorMessage = '网络请求失败，请检查网络连接后重试';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 清空结果，回到输入态
  void reset() {
    analysisData = null;
    stockCode = '';
    hasError = false;
    errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }
}
