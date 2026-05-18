# 股票分析助手APP - 快速开始指南

## 环境要求

- Windows 10/11
- 至少 4GB 可用内存
- 至少 10GB 可用磁盘空间
- 网络连接

## 快速开始（3步完成）

### 第1步：环境搭建

**以管理员身份运行** `setup_windows.bat`

右键点击 `setup_windows.bat` → 选择"以管理员身份运行"

这个脚本会自动：
- ✅ 检查并安装 Git
- ✅ 检查并安装 Java
- ✅ 下载 Flutter SDK（使用国内镜像）
- ✅ 配置环境变量
- ✅ 下载 Android SDK
- ✅ 安装必要的SDK组件
- ✅ 验证环境

**注意**：此过程可能需要 10-30 分钟，取决于网络速度。

### 第2步：编译APK

环境搭建完成后，**重新打开命令提示符**，然后运行：

```cmd
cd D:\soft\stock_analyzer_app
compile.bat
```

或者双击运行 `compile.bat`

编译过程包括：
1. 清理旧构建
2. 获取依赖（使用国内镜像加速）
3. 代码分析
4. 运行测试
5. 构建Release APK

**注意**：首次编译可能需要 5-15 分钟。

### 第3步：安装APK

编译成功后，APK文件会生成在：
- `D:\soft\stock_analyzer_app\stock_analyzer_app.apk`

安装到手机：
1. 将APK文件传输到手机
2. 在手机上点击安装
3. 如提示"未知来源"，请前往设置 → 安全 → 允许未知来源

或使用ADB安装：
```cmd
adb install stock_analyzer_app.apk
```

## 常见问题

### 1. 脚本无法运行

**问题**：提示"请以管理员身份运行"

**解决**：右键点击脚本 → 选择"以管理员身份运行"

### 2. Flutter下载失败

**问题**：下载速度慢或失败

**解决**：脚本已配置国内镜像，如仍失败可手动下载：
```cmd
git clone https://gitee.com/mirrors/Flutter.git C:\flutter -b stable
```

### 3. 编译失败 - Android SDK未找到

**问题**：提示"Android SDK not found"

**解决**：
1. 安装 Android Studio：https://developer.android.com/studio
2. 或手动设置环境变量：
```cmd
setx ANDROID_SDK_ROOT "C:\Users\%USERNAME%\AppData\Local\Android\Sdk"
```

### 4. 编译失败 - 缺少Android许可证

**问题**：提示"Android licenses not accepted"

**解决**：
```cmd
flutter doctor --android-licenses
```
然后全部输入 `y` 接受

### 5. 依赖下载失败

**问题**：`flutter pub get` 失败

**解决**：设置国内镜像后重试：
```cmd
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter pub get
```

### 6. 内存不足

**问题**：编译过程中卡住或崩溃

**解决**：
- 关闭其他程序释放内存
- 增加虚拟内存（建议至少8GB）
- 使用 `--verbose` 查看详细日志

## 手动编译（备用方案）

如果脚本无法使用，可以手动执行：

```cmd
:: 1. 进入项目目录
cd D:\soft\stock_analyzer_app

:: 2. 设置国内镜像
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

:: 3. 获取依赖
flutter pub get

:: 4. 构建APK
flutter build apk --release

:: 5. APK位置
:: build\app\outputs\flutter-apk\app-release.apk
```

## 验证安装

运行以下命令检查环境：

```cmd
flutter doctor
```

所有项目都应该是 ✓ 或 !，不应该有 ✗。

## 需要帮助？

1. 查看详细日志：`flutter doctor -v`
2. Flutter官方文档：https://flutter.dev/docs
3. 国内镜像文档：https://flutter.cn

## 文件说明

| 文件 | 说明 |
|-----|------|
| `setup_windows.bat` | 环境搭建脚本（管理员运行） |
| `compile.bat` | 编译脚本 |
| `QUICK_START.md` | 本快速指南 |
| `INSTALL.md` | 详细安装文档 |
| `README.md` | 项目说明 |

## 下一步

编译完成后，你就可以：
1. 在Android手机上安装APK
2. 开始体验股票分析助手APP
3. 查看实时行情、K线分析、财报解读等功能

祝你使用愉快！
