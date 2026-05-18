import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/user_provider.dart';

/// 个人中心页面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '我的',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 设置页面
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 用户信息
            _buildUserHeader(),
            
            SizedBox(height: 16.h),
            
            // 资产概览
            _buildAssetOverview(),
            
            SizedBox(height: 16.h),
            
            // 功能列表
            _buildFunctionList(),
          ],
        ),
      ),
    );
  }

  /// 构建用户头部
  Widget _buildUserHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32.r),
            ),
            child: Icon(
              Icons.person,
              size: 32.sp,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '股票小白',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '投资新手，正在学习中',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  /// 构建资产概览
  Widget _buildAssetOverview() {
    return Consumer<UserProvider>(
      builder: (context, provider, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '总资产 (元)',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                provider.totalPortfolioValue.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '累计收益',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${provider.totalPortfolioProfit >= 0 ? '+' : ''}${provider.totalPortfolioProfit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: provider.totalPortfolioProfit >= 0 
                                ? Colors.white 
                                : Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '收益率',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '${provider.totalPortfolioReturn >= 0 ? '+' : ''}${provider.totalPortfolioReturn.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: provider.totalPortfolioReturn >= 0 
                                ? Colors.white 
                                : Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建功能列表
  Widget _buildFunctionList() {
    final functions = [
      {'icon': Icons.star, 'label': '自选股', 'color': Colors.amber},
      {'icon': Icons.pie_chart, 'label': '投资组合', 'color': Colors.blue},
      {'icon': Icons.history, 'label': '分析历史', 'color': Colors.green},
      {'icon': Icons.notifications, 'label': '消息通知', 'color': Colors.orange},
      {'icon': Icons.help_outline, 'label': '帮助中心', 'color': Colors.purple},
      {'icon': Icons.feedback_outlined, 'label': '意见反馈', 'color': Colors.teal},
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: functions.map((func) {
          return ListTile(
            leading: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: (func['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                func['icon'] as IconData,
                color: func['color'] as Color,
                size: 20.sp,
              ),
            ),
            title: Text(func['label'] as String),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            onTap: () {
              // TODO: 导航到对应页面
            },
          );
        }).toList(),
      ),
    );
  }
}
