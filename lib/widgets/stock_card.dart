import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../config/theme.dart';
import '../models/stock.dart';

/// 股票卡片组件 - 支持 Stock 和 StockItem
class StockCard extends StatelessWidget {
  final dynamic stock;  // Stock 或 StockItem
  final VoidCallback? onTap;

  const StockCard({
    super.key,
    required this.stock,
    this.onTap,
  });

  // 获取名称
  String get _name => stock is Stock ? (stock as Stock).name : (stock as StockItem).name;
  
  // 获取代码
  String get _code => stock is Stock ? (stock as Stock).code : (stock as StockItem).code;
  
  // 获取价格
  double get _price => stock is Stock ? (stock as Stock).currentPrice : (stock as StockItem).price;
  
  // 获取涨跌幅
  double get _changePercent => stock is Stock ? (stock as Stock).changePercent : (stock as StockItem).changePercent;
  
  // 是否上涨
  bool get _isUp => _changePercent > 0;
  
  // 是否下跌
  bool get _isDown => _changePercent < 0;

  @override
  Widget build(BuildContext context) {
    final color = _isUp ? AppTheme.upColor : 
                  _isDown ? AppTheme.downColor : AppTheme.neutralColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            // 股票信息
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _code,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            
            // 最新价
            Expanded(
              child: Text(
                _price.toStringAsFixed(2),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // 涨跌幅
            Expanded(
              child: Container(
                margin: EdgeInsets.only(left: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '${_isUp ? '+' : ''}${_changePercent.toStringAsFixed(2)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 简洁股票卡片
class SimpleStockCard extends StatelessWidget {
  final String name;
  final String code;
  final double price;
  final double changePercent;
  final VoidCallback? onTap;

  const SimpleStockCard({
    super.key,
    required this.name,
    required this.code,
    required this.price,
    required this.changePercent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = changePercent > 0;
    final isDown = changePercent < 0;
    final color = isUp ? AppTheme.upColor : isDown ? AppTheme.downColor : AppTheme.neutralColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140.w,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              code,
              style: TextStyle(
                fontSize: 11.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  price.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
