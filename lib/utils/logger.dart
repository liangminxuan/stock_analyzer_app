import 'package:flutter/foundation.dart';

/// 统一日志入口。
///
/// 背景：项目此前直接使用 `print()`（静态分析共 63 处），既会触发
/// `avoid_print`，又会在 release 包中把调试信息写进 logcat。
///
/// 约定：
/// - 业务代码一律调用 [logDebug] / [logError]，不要直接用 `print()` ；
/// - release 构建默认静默；需要线上排查时可把 [verboseLogging] 置为 true。
bool verboseLogging = kDebugMode;

/// 调试日志（默认仅在 debug 构建输出）
void logDebug(Object? message) {
  if (verboseLogging) {
    debugPrint('[debug] $message');
  }
}

/// 错误日志（默认仅在 debug 构建输出，但始终保留调用点便于接入上报）
void logError(Object? message, [Object? error, StackTrace? stackTrace]) {
  if (verboseLogging) {
    debugPrint('[error] $message${error == null ? '' : ' | $error'}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
