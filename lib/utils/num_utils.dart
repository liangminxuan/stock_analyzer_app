/// 数值解析工具。
///
/// 背景：后端（Python）返回的 JSON 里，同一个字段可能是 `int` 也可能是
/// `double`（例如涨跌幅 5 与 5.26）。Dart 里 `(json['x'] ?? 0) as double`
/// 在遇到 `int` 时会直接抛 `type 'int' is not a subtype of type 'double'`，
/// 导致整页构建失败（见 AUDIT_REPORT 修复记录）。
///
/// 统一用这里的函数做转换，避免散落的强制类型转换。
library;

/// 安全转 double：支持 num / 数字字符串 / null。
double asDouble(Object? value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// 安全转 int：支持 num / 数字字符串 / null。
int asInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// 安全取列表：非 List 或 null 时返回空列表。
List<T> asList<T>(Object? value) {
  if (value is List) {
    return value.whereType<T>().toList(growable: false);
  }
  return const [];
}

/// 安全取 Map（键值都按 String/dynamic 处理）。
Map<String, dynamic>? asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
