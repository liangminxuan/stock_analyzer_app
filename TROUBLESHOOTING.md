# 股票分析助手APP - 故障排除指南

## 环境搭建问题

### 问题1: PowerShell执行策略限制

**错误信息：**
```
无法加载文件，因为在此系统上禁止运行脚本
```

**解决方案：**
```powershell
# 以管理员身份运行PowerShell，执行：
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# 输入 Y 确认
```

### 问题2: 无法下载Flutter

**错误信息：**
```
fatal: unable to access 'https://github.com/...'
```

**解决方案：**
```cmd
:: 使用国内镜像
git clone https://gitee.com/mirrors/Flutter.git C:\flutter -b stable

:: 或者设置代理
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
```

### 问题3: 环境变量未生效

**现象：** 安装完成后，新开命令窗口仍找不到flutter命令

**解决方案：**
```cmd
:: 手动添加环境变量
setx PATH "C:\flutter\bin;%PATH%" /M

:: 或者手动编辑系统环境变量
:: 1. Win+R 运行 sysdm.cpl
:: 2. 高级 → 环境变量
:: 3. 编辑 Path，添加 C:\flutter\bin
```

## 编译问题

### 问题4: Gradle下载失败

**错误信息：**
```
Could not resolve all files for configuration 'classpath'
```

**解决方案：**
编辑 `android/build.gradle`，修改repositories：
```gradle
buildscript {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/jcenter' }
        maven { url 'https://maven.aliyun.com/nexus/content/groups/public' }
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/jcenter' }
        maven { url 'https://maven.aliyun.com/nexus/content/groups/public' }
        google()
        mavenCentral()
    }
}
```

### 问题5: 依赖冲突

**错误信息：**
```
Because stock_analyzer_app depends on ...
```

**解决方案：**
```cmd
:: 清理并重新获取依赖
flutter clean
flutter pub cache repair
flutter pub get
```

### 问题6: 编译内存不足

**错误信息：**
```
java.lang.OutOfMemoryError: Java heap space
```

**解决方案：**
编辑 `android/gradle.properties`，添加：
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=512m
org.gradle.parallel=true
org.gradle.daemon=true
```

### 问题7: NDK版本不匹配

**错误信息：**
```
No version of NDK matched the requested version
```

**解决方案：**
```cmd
:: 安装NDK
sdkmanager "ndk;25.1.8937393"

:: 或者在 android/app/build.gradle 中指定NDK版本
android {
    ndkVersion "25.1.8937393"
}
```

### 问题8: 编译器版本过低

**错误信息：**
```
The current Dart SDK version is ...
```

**解决方案：**
```cmd
:: 升级Flutter
flutter upgrade

:: 或者降级SDK约束
:: 编辑 pubspec.yaml，修改 sdk 版本
```

## 运行时问题

### 问题9: APP安装失败

**错误信息：**
```
INSTALL_FAILED_ALREADY_EXISTS
```

**解决方案：**
```cmd
:: 卸载旧版本
adb uninstall com.example.stock_analyzer_app

:: 重新安装
adb install stock_analyzer_app.apk
```

### 问题10: APP闪退

**可能原因及解决方案：**

1. **缺少权限**
   - 检查AndroidManifest.xml是否包含网络权限

2. **网络问题**
   - 检查手机网络连接
   - 检查是否允许APP使用网络

3. **数据解析错误**
   - 检查API返回数据格式
   - 查看日志：`adb logcat | grep flutter`

## 调试技巧

### 查看详细日志

```cmd
:: Flutter详细日志
flutter build apk --release --verbose

:: Android设备日志
adb logcat -s flutter

:: 过滤特定标签
adb logcat -s "StockAnalyzer:*"
```

### 清理所有缓存

```cmd
:: 清理Flutter缓存
flutter clean

:: 清理Gradle缓存
cd android
gradlew clean

:: 清理Pub缓存
flutter pub cache clean

:: 重新获取依赖
flutter pub get
```

### 检查环境配置

```cmd
:: 检查Flutter环境
flutter doctor -v

:: 检查Android设备
flutter devices

:: 检查Gradle版本
cd android
gradlew --version
```

## 性能优化

### 减小APK体积

编辑 `android/app/build.gradle`：
```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 启用代码压缩

创建 `android/app/proguard-rules.pro`：
```proguard
# Flutter ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
```

## 联系支持

如果以上方案都无法解决问题，请提供以下信息寻求帮助：

1. 完整的错误日志
2. 运行 `flutter doctor -v` 的输出
3. 操作系统版本
4. 项目版本号

## 常用命令速查

```cmd
:: 环境检查
flutter doctor

:: 获取依赖
flutter pub get

:: 运行应用
flutter run

:: 构建APK
flutter build apk --release

:: 构建AAB（Google Play）
flutter build appbundle --release

:: 清理项目
flutter clean

:: 查看日志
flutter logs

:: 分析代码
flutter analyze

:: 运行测试
flutter test
```
