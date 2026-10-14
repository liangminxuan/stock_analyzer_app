import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 测试用 Dio 适配器：按请求 URL 返回预置响应，避免真实网络请求。
typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;

  /// 记录实际请求过的 URL，便于断言
  final List<String> requestedUris = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUris.add(options.uri.toString());
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// 纯文本响应（腾讯行情/搜索接口用）
ResponseBody textBody(String body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.textPlainContentType],
    },
  );
}

/// JSON 响应（东财 K线/后端接口用）
ResponseBody jsonBody(Object data, {int statusCode = 200}) {
  return ResponseBody.fromString(
    json.encode(data),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

/// 构造腾讯行情接口的一行数据（`~` 分隔 50 个字段）
///
/// 字段位置与线上一致：1=名称、3=现价、4=昨收、5=开盘、6=成交量、
/// 31=涨跌额、32=涨跌幅、33=最高、34=最低、37=成交额、39=PE、44=总市值。
String tencentQuoteLine({
  required String code,
  String name = '测试股票',
  double price = 10.0,
  double previousClose = 9.5,
  double open = 9.6,
  double high = 10.5,
  double low = 9.4,
  int volume = 12345,
  double turnover = 6789.0,
  double change = 0.5,
  double changePercent = 5.26,
  double pe = 15.0,
  double marketCap = 100.0,
}) {
  final fields = List<String>.filled(50, '0');
  fields[0] = '1';
  fields[1] = name;
  fields[2] = code;
  fields[3] = price.toStringAsFixed(2);
  fields[4] = previousClose.toStringAsFixed(2);
  fields[5] = open.toStringAsFixed(2);
  fields[6] = volume.toString();
  for (var i = 0; i < 5; i++) {
    fields[9 + i * 2] = (price - 0.01 * (i + 1)).toStringAsFixed(2);
    fields[10 + i * 2] = '${100 + i}';
    fields[19 + i * 2] = (price + 0.01 * (i + 1)).toStringAsFixed(2);
    fields[20 + i * 2] = '${200 + i}';
  }
  fields[31] = change.toStringAsFixed(2);
  fields[32] = changePercent.toStringAsFixed(2);
  fields[33] = high.toStringAsFixed(2);
  fields[34] = low.toStringAsFixed(2);
  fields[37] = turnover.toStringAsFixed(2);
  fields[39] = pe.toStringAsFixed(2);
  fields[44] = marketCap.toStringAsFixed(2);

  final prefix = code.startsWith('6') || code.startsWith('5')
      ? 'sh$code'
      : code.startsWith('8')
          ? 'bj$code'
          : 'sz$code';
  return 'v_$prefix="${fields.join('~')}";\n';
}
