# 股票分析助手APP - 安装指南

## 方式一：直接安装APK（推荐）

### 前提条件
1. 安装Flutter SDK
2. 安装Android SDK
3. 配置环境变量

### 快速开始

#### 1. 安装Flutter

**Windows:**
```powershell
# 下载Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable

# 添加到PATH
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\flutter\bin", "User")
```

**Mac/Linux:**
```bash
# 下载Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable

# 添加到PATH
export PATH="$PWD/flutter/bin:$PATH"
```

#### 2. 安装Android SDK

下载Android Studio并安装Android SDK:
https://developer.android.com/studio

设置环境变量:
```bash
# Mac/Linux
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin

# Windows
setx ANDROID_SDK_ROOT "C:\Users\%USERNAME%\AppData\Local\Android\Sdk"
```

#### 3. 运行构建脚本

```bash
cd stock_analyzer_app
chmod +x build_apk.sh
./build_apk.sh
```

或者手动构建:
```bash
cd stock_analyzer_app
flutter pub get
flutter build apk --release
```

#### 4. 获取APK

构建完成后，APK文件位于:
- `build/app/outputs/flutter-apk/app-release.apk`
- 或项目根目录的 `stock_analyzer_app.apk`

## 方式二：开发模式运行

### 连接真机或启动模拟器

```bash
# 检查设备
flutter devices

# 运行应用
flutter run
```

### 热重载

在开发过程中，按 `r` 键进行热重载，按 `R` 键进行热重启。

## 常见问题

### 1. Flutter命令找不到

确保Flutter的bin目录已添加到PATH环境变量。

### 2. Android SDK未找到

设置ANDROID_SDK_ROOT环境变量:
```bash
export ANDROID_SDK_ROOT=/path/to/android/sdk
```

### 3. 构建失败

运行诊断命令:
```bash
flutter doctor
```

根据提示修复问题。

### 4. 依赖下载慢（国内用户）

设置国内镜像:
```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 系统要求

- **操作系统**: Windows 10+, macOS 10.14+, Linux
- **磁盘空间**: 至少2.5GB（不包括IDE/工具链）
- **Flutter SDK**: >= 3.0.0
- **Android SDK**: API 21+

## 安装验证

运行以下命令验证安装:
```bash
flutter doctor
```

所有勾选都应该是绿色的，表示环境配置正确。

## 下一步

构建完成后，将APK文件传输到Android设备安装即可使用。

安装命令:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```
