import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_analyzer_app/screens/discovery/ai_analysis_screen.dart';
import 'package:stock_analyzer_app/services/backend_service.dart';

import '../helpers/fake_adapter.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(home: child),
  );
}

/// 用真实手机尺寸（375x812）渲染，避免默认 800x600 视口放大字号造成误判
Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap(const AIAnalysisScreen()));
}

void main() {
  testWidgets('AI 分析页初始渲染输入视图', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('AI 对冲基金分析'), findsOneWidget);
    expect(find.text('输入股票代码'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // 未输入代码时，底部大按钮不可点
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '开始 AI 分析'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('输入 6 位代码后按钮可用', (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '600519');
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '开始 AI 分析'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('后端返回失败时展示可读错误（不崩溃）', (tester) async {
    BackendService().dio.httpClientAdapter = FakeAdapter(
      (_) => jsonBody({'success': false, 'error': '行情数据正在准备中，请稍后重试'}),
    );

    await _pumpScreen(tester);
    await tester.enterText(find.byType(TextField), '600519');
    await tester.pump();

    final startButton = find.widgetWithText(ElevatedButton, '开始 AI 分析');
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.text('行情数据正在准备中，请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  test('控制器：非法代码（非 6 位）直接提示，不发请求', () async {
    var requested = 0;
    BackendService().dio.httpClientAdapter = FakeAdapter((_) {
      requested++;
      return jsonBody({'success': true});
    });

    final controller = AIAnalysisController();
    controller.stockCode = '600';
    await controller.startAnalysis();

    expect(controller.hasError, isTrue);
    expect(controller.errorMessage, '请输入正确的6位股票代码');
    expect(controller.isLoading, isFalse);
    expect(requested, 0);
    controller.dispose();
  });

  test('控制器：成功返回时写入 analysisData 并复位 loading', () async {
    BackendService().dio.httpClientAdapter = FakeAdapter(
      (_) => jsonBody({'success': true, 'overall': {'signal': 'bullish'}}),
    );

    final controller = AIAnalysisController();
    var notified = 0;
    controller.addListener(() => notified++);

    controller.stockCode = '600519';
    await controller.startAnalysis();

    expect(controller.hasError, isFalse);
    expect(controller.analysisData, isNotNull);
    expect(controller.analysisData!['success'], isTrue);
    expect(controller.isLoading, isFalse);
    expect(notified, greaterThan(0));
    controller.dispose();
  });
}
