import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../config/theme.dart';
import '../models/kline.dart';

/// K线图组件 - 蜡烛图+均线
class KLineChart extends StatefulWidget {
  final List<KLineData> data;
  final Function(int index)? onTap;

  const KLineChart({
    super.key,
    required this.data,
    this.onTap,
  });

  @override
  State<KLineChart> createState() => _KLineChartState();
}

class _KLineChartState extends State<KLineChart> {
  int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    return Column(
      children: [
        // 选中数据显示
        if (selectedIndex != null && selectedIndex! < widget.data.length)
          _buildInfoBar(widget.data[selectedIndex!]),
        
        // K线图（蜡烛图+均线）
        Expanded(
          flex: 3,
          child: _buildCandlestickChart(),
        ),
        
        // 成交量图
        Expanded(
          flex: 1,
          child: _buildVolumeChart(),
        ),
      ],
    );
  }

  /// 构建信息栏
  Widget _buildInfoBar(KLineData data) {
    final color = data.isUp ? AppTheme.upColor : AppTheme.downColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('开: ${data.open.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp)),
          Text('高: ${data.high.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: AppTheme.upColor)),
          Text('低: ${data.low.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: AppTheme.downColor)),
          Text('收: ${data.close.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: color, fontWeight: FontWeight.bold)),
          if (data.ma5 != null) Text('MA5: ${data.ma5!.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: AppTheme.kLineMa5)),
          if (data.ma10 != null) Text('MA10: ${data.ma10!.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: AppTheme.kLineMa10)),
          if (data.ma20 != null) Text('MA20: ${data.ma20!.toStringAsFixed(2)}', style: TextStyle(fontSize: 11.sp, color: AppTheme.kLineMa20)),
        ],
      ),
    );
  }

  /// 构建蜡烛图
  Widget _buildCandlestickChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) {
            final width = constraints.maxWidth;
            final itemWidth = width / widget.data.length;
            final index = (details.localPosition.dx / itemWidth).floor();
            if (index >= 0 && index < widget.data.length) {
              setState(() {
                selectedIndex = index;
              });
              widget.onTap?.call(index);
            }
          },
          onHorizontalDragUpdate: (details) {
            final width = constraints.maxWidth;
            final itemWidth = width / widget.data.length;
            final index = (details.localPosition.dx / itemWidth).floor();
            if (index >= 0 && index < widget.data.length) {
              setState(() {
                selectedIndex = index;
              });
            }
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: CandlestickPainter(
              data: widget.data,
              selectedIndex: selectedIndex,
            ),
          ),
        );
      },
    );
  }

  /// 构建成交量图
  Widget _buildVolumeChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: VolumePainter(data: widget.data),
        );
      },
    );
  }
}

/// 蜡烛图画笔
class CandlestickPainter extends CustomPainter {
  final List<KLineData> data;
  final int? selectedIndex;

  CandlestickPainter({
    required this.data,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minPrice = data.map((d) => d.low).reduce((a, b) => a < b ? a : b);
    final maxPrice = data.map((d) => d.high).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    
    final itemWidth = size.width / data.length;
    final candleWidth = itemWidth * 0.7;

    // 绘制网格线
    _drawGrid(canvas, size, minPrice, maxPrice, priceRange);

    // 绘制蜡烛
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = i * itemWidth + itemWidth / 2;
      
      final color = d.isUp ? AppTheme.upColor : AppTheme.downColor;
      
      // 计算Y坐标
      double priceToY(double price) {
        if (priceRange == 0) return size.height / 2;
        return size.height - ((price - minPrice) / priceRange) * size.height;
      }

      final yOpen = priceToY(d.open);
      final yClose = priceToY(d.close);
      final yHigh = priceToY(d.high);
      final yLow = priceToY(d.low);

      // 绘制影线
      final shadowPaint = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, yHigh),
        Offset(x, yLow),
        shadowPaint,
      );

      // 绘制实体
      final bodyTop = yOpen < yClose ? yOpen : yClose;
      final bodyBottom = yOpen < yClose ? yClose : yOpen;
      final bodyHeight = (bodyBottom - bodyTop).abs();
      
      final bodyPaint = Paint()
        ..color = color
        ..style = d.isUp ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1;
      
      canvas.drawRect(
        Rect.fromLTRB(
          x - candleWidth / 2,
          bodyTop,
          x + candleWidth / 2,
          bodyBottom < bodyTop + 1 ? bodyTop + 1 : bodyBottom,
        ),
        bodyPaint,
      );

      // 选中高亮
      if (selectedIndex == i) {
        final highlightPaint = Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTRB(x - itemWidth / 2, 0, x + itemWidth / 2, size.height),
          highlightPaint,
        );
      }
    }

    // 绘制均线
    _drawMA(canvas, size, minPrice, priceRange, itemWidth);
  }

  void _drawGrid(Canvas canvas, Size size, double minPrice, double maxPrice, double priceRange) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;

    // 水平网格线
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawMA(Canvas canvas, Size size, double minPrice, double priceRange, double itemWidth) {
    if (priceRange == 0) return;

    double priceToY(double price) {
      return size.height - ((price - minPrice) / priceRange) * size.height;
    }

    // MA5
    _drawMALine(canvas, data.map((d) => d.ma5).toList(), AppTheme.kLineMa5, itemWidth, priceToY);
    // MA10
    _drawMALine(canvas, data.map((d) => d.ma10).toList(), AppTheme.kLineMa10, itemWidth, priceToY);
    // MA20
    _drawMALine(canvas, data.map((d) => d.ma20).toList(), AppTheme.kLineMa20, itemWidth, priceToY);
  }

  void _drawMALine(Canvas canvas, List<double?> maValues, Color color, double itemWidth, double Function(double) priceToY) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;

    for (int i = 0; i < maValues.length; i++) {
      final ma = maValues[i];
      if (ma == null || ma == 0) continue;

      final x = i * itemWidth + itemWidth / 2;
      final y = priceToY(ma);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 成交量画笔
class VolumePainter extends CustomPainter {
  final List<KLineData> data;

  VolumePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVolume = data.map((d) => d.volume).reduce((a, b) => a > b ? a : b);
    if (maxVolume == 0) return;

    final itemWidth = size.width / data.length;
    final barWidth = itemWidth * 0.7;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final x = i * itemWidth + itemWidth / 2;
      
      final color = d.isUp ? AppTheme.upColor : AppTheme.downColor;
      final barHeight = (d.volume / maxVolume) * size.height;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTRB(
          x - barWidth / 2,
          size.height - barHeight,
          x + barWidth / 2,
          size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter) => true;
}

/// 简化的K线展示组件
class MiniKLineChart extends StatelessWidget {
  final List<double> prices;
  final double width;
  final double height;
  final Color? lineColor;

  const MiniKLineChart({
    super.key,
    required this.prices,
    this.width = 60,
    this.height = 30,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) {
      return SizedBox(width: width, height: height);
    }

    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = maxPrice - minPrice;

    final color = lineColor ?? 
        (prices.last > prices.first ? AppTheme.upColor : AppTheme.downColor);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _MiniKLinePainter(
          prices: prices,
          minPrice: minPrice,
          range: range,
          color: color,
        ),
      ),
    );
  }
}

/// 迷你K线绘制器
class _MiniKLinePainter extends CustomPainter {
  final List<double> prices;
  final double minPrice;
  final double range;
  final Color color;

  _MiniKLinePainter({
    required this.prices,
    required this.minPrice,
    required this.range,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (prices.length - 1);

    for (int i = 0; i < prices.length; i++) {
      final x = i * stepX;
      final y = range > 0
          ? size.height - ((prices[i] - minPrice) / range) * size.height
          : size.height / 2;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // 绘制渐变填充
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
