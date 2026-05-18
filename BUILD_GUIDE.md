# 股票分析助手 APP - 构建指南

## 方案一：使用 Windows 本地环境构建（推荐）

### 前置要求
1. Windows 10/11 系统
2. 已安装 Git

### 快速开始

#### 步骤 1：安装 Flutter 和 Android SDK
运行项目中的自动安装脚本：

```batch
# 以管理员身份运行 CMD 或 PowerShell
cd stock_analyzer_app
setup_windows.bat
```

此脚本会自动：
- 下载 Flutter SDK (3.24.5) 并配置环境变量
- 下载 Android SDK Command Line Tools
- 安装必要的 Android 平台 (android-34) 和构建工具
- 验证安装

#### 步骤 2：编译 APK
```batch
compile.bat
```

编译成功后，APK 文件位于：
```
build\app\outputs\flutter-apk\app-release.apk
```

---

## 方案二：手动安装步骤

### 1. 安装 Flutter SDK

```batch
# 下载 Flutter 3.24.5
curl -L -o flutter_windows_3.24.5-stable.zip "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"

# 解压到 C:\flutter
powershell -Command "Expand-Archive flutter_windows_3.24.5-stable.zip C:\"

# 添加环境变量
setx PATH "%PATH%;C:\flutter\bin"
```

### 2. 安装 Android SDK

```batch
# 下载 Command Line Tools
mkdir C:\Android\cmdline-tools
curl -L -o cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
powershell -Command "Expand-Archive cmdline-tools.zip C:\Android\cmdline-tools"

# 重命名为 latest
move C:\Android\cmdline-tools\cmdline-tools C:\Android\cmdline-tools\latest

# 添加环境变量
setx ANDROID_HOME "C:\Android"
setx PATH "%PATH%;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools"
```

### 3. 安装必要的 SDK 组件

```batch
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "build-tools;30.0.3"
```

### 4. 编译 APK

```batch
flutter clean
flutter pub get
flutter build apk --release
```

---

## 项目依赖说明

本项目已精简依赖，仅使用以下必要包：

| 包名 | 用途 |
|------|------|
| dio | 网络请求（获取股票数据）|
| provider | 状态管理 |
| fl_chart | K线图和图表展示 |
| flutter_screenutil | 屏幕适配 |
| shimmer | 加载动画效果 |

已移除的依赖（减少构建问题）：
- path_provider
- url_launcher
- shared_preferences
- intl

---

## 常见问题

### 1. Gradle 下载失败
编辑 `android\gradle\wrapper\gradle-wrapper.properties`，使用国内镜像：
```properties
distributionUrl=https\://repo.huaweicloud.com/gradle/gradle-7.6.3-all.zip
```

### 2. Maven 依赖下载慢
编辑 `android\build.gradle`，在 `allprojects.repositories` 中添加阿里云镜像：
```gradle
allprojects {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        google()
        mavenCentral()
    }
}
```

### 3. 编译时出现 `StockType.index` 冲突
此问题已修复。如果仍遇到，将 `lib/config/constants.dart` 中的 `index` 改为 `indexStock`。

---

## 功能特性

- 📈 实时股票行情（A股、港股、美股）
- 📊 K线图展示（MA、MACD、KDJ、RSI、BOLL 指标）
- 🤖 AI 智能分析（K线形态、财报解读、公告分析）
- 🔍 股票搜索
- 📰 财经资讯

---

## 数据来源

- 新浪财经 API (hq.sinajs.cn)
- 腾讯财经 API (qt.gtimg.cn)
- 东方财富 API (push2his.eastmoney.com)

所有数据接口均为免费公开接口。

---

## 技术栈

- Flutter 3.24.5
- Dart 3.5.4
- Android SDK 34
- Gradle 7.6.3
- JDK 17
