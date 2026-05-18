import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// 加载组件
class LoadingWidget extends StatelessWidget {
  final double? height;

  const LoadingWidget({super.key, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40.w,
            height: 40.w,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (height != null) ...[
            SizedBox(height: 16.h),
            Text(
              '加载中...',
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 骨架屏组件
class ShimmerWidget extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surface,
      highlightColor: Theme.of(context).colorScheme.surface.withOpacity(0.5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// 股票卡片骨架屏
class StockCardShimmer extends StatelessWidget {
  const StockCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerWidget(width: 80.w, height: 16.h),
                SizedBox(height: 8.h),
                ShimmerWidget(width: 60.w, height: 12.h),
              ],
            ),
          ),
          ShimmerWidget(width: 60.w, height: 16.h),
          SizedBox(width: 12.w),
          ShimmerWidget(width: 70.w, height: 28.h),
        ],
      ),
    );
  }
}

/// 错误组件
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48.sp,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 空数据组件
class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData? icon;

  const EmptyWidget({
    super.key,
    this.message = '暂无数据',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            size: 64.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
