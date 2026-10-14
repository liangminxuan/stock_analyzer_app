/// 数据接口异常。
///
/// 背景（见 AUDIT_REPORT.md P0-1）：此前接口失败时会返回写死的"假行情"
/// （贵州茅台 1315.0、上证指数 3100.0 等），界面上无法分辨真假。
/// 现在统一改为抛出本异常，由 Provider 捕获后在界面显示错误态与重试入口。
class ApiException implements Exception {
  /// 面向用户的中文提示
  final String message;

  /// 原始异常/响应，便于日志排查
  final Object? cause;

  const ApiException(this.message, {this.cause});

  @override
  String toString() => 'ApiException: $message${cause == null ? '' : ' ($cause)'}';
}

/// 把任意异常转换为面向用户的中文提示。
///
/// Provider 层统一用它给 `error` 赋值，避免把 `DioException(...)` 之类的
/// 原始信息直接显示给用户。
String describeError(Object error) {
  if (error is ApiException) return error.message;
  return '网络异常，请检查网络后重试';
}
