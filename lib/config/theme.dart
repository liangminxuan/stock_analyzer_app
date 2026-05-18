import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 应用主题配置
class AppTheme {
  // 主色调 - 股市红
  static const Color primaryColor = Color(0xFFE74C3C);
  static const Color primaryLight = Color(0xFFFADBD8);
  static const Color primaryDark = Color(0xFFC0392B);
  
  // 涨跌色
  static const Color upColor = Color(0xFFE74C3C);      // 涨 - 红色
  static const Color downColor = Color(0xFF27AE60);    // 跌 - 绿色
  static const Color neutralColor = Color(0xFF7F8C8D); // 平 - 灰色
  
  // 背景色
  static const Color backgroundLight = Color(0xFFF5F6FA);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF16213E);
  
  // 文字色
  static const Color textPrimaryLight = Color(0xFF2C3E50);
  static const Color textSecondaryLight = Color(0xFF7F8C8D);
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  
  // 功能色
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);
  
  // K线颜色
  static const Color kLineUp = Color(0xFFE74C3C);
  static const Color kLineDown = Color(0xFF27AE60);
  static const Color kLineMa5 = Color(0xFFFFA500);
  static const Color kLineMa10 = Color(0xFF9B59B6);
  static const Color kLineMa20 = Color(0xFF3498DB);
  static const Color kLineMa60 = Color(0xFF2ECC71);

  /// 浅色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: info,
        surface: surfaceLight,
        background: backgroundLight,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onBackground: textPrimaryLight,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: surfaceLight,
        foregroundColor: textPrimaryLight,
        titleTextStyle: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: textPrimaryLight,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        color: surfaceLight,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: textPrimaryLight),
        displayMedium: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: textPrimaryLight),
        displaySmall: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: textPrimaryLight),
        headlineLarge: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: textPrimaryLight),
        titleLarge: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: textPrimaryLight),
        titleMedium: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: textPrimaryLight),
        titleSmall: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: textPrimaryLight),
        bodyLarge: TextStyle(fontSize: 16.sp, color: textPrimaryLight),
        bodyMedium: TextStyle(fontSize: 14.sp, color: textPrimaryLight),
        bodySmall: TextStyle(fontSize: 12.sp, color: textSecondaryLight),
        labelLarge: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: textSecondaryLight),
        labelMedium: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: textSecondaryLight),
        labelSmall: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: textSecondaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: primaryColor, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }

  /// 深色主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: info,
        surface: surfaceDark,
        background: backgroundDark,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryDark,
        onBackground: textPrimaryDark,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: surfaceDark,
        foregroundColor: textPrimaryDark,
        titleTextStyle: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        color: surfaceDark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: textPrimaryDark),
        displayMedium: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: textPrimaryDark),
        displaySmall: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: textPrimaryDark),
        headlineLarge: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w600, color: textPrimaryDark),
        headlineMedium: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: textPrimaryDark),
        headlineSmall: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: textPrimaryDark),
        titleLarge: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: textPrimaryDark),
        titleMedium: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: textPrimaryDark),
        titleSmall: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: textPrimaryDark),
        bodyLarge: TextStyle(fontSize: 16.sp, color: textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14.sp, color: textPrimaryDark),
        bodySmall: TextStyle(fontSize: 12.sp, color: textSecondaryDark),
        labelLarge: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: textSecondaryDark),
        labelMedium: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: textSecondaryDark),
        labelSmall: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: textSecondaryDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: primaryColor, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }
}

/// 扩展方法，方便获取颜色
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  bool get isDarkMode => theme.brightness == Brightness.dark;
}
