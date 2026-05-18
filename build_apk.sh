#!/bin/bash

# 股票分析助手APP - APK构建脚本

echo "=========================================="
echo "  股票分析助手APP - APK构建脚本"
echo "=========================================="
echo ""

# 检查Flutter环境
if ! command -v flutter &> /dev/null; then
    echo "错误: 未找到Flutter命令"
    echo ""
    echo "请先安装Flutter SDK:"
    echo "1. 访问 https://flutter.dev/docs/get-started/install"
    echo "2. 下载并解压Flutter SDK"
    echo "3. 将 flutter/bin 添加到系统PATH"
    echo ""
    echo "或者使用以下命令安装(国内用户):"
    echo "git clone https://github.com/flutter/flutter.git -b stable"
    echo "export PATH=\"\$PWD/flutter/bin:\$PATH\""
    exit 1
fi

echo "✓ Flutter已安装"
flutter --version
echo ""

# 检查Android SDK
if [ -z "$ANDROID_SDK_ROOT" ] && [ -z "$ANDROID_HOME" ]; then
    echo "警告: 未设置ANDROID_SDK_ROOT或ANDROID_HOME环境变量"
    echo "请确保Android SDK已正确配置"
    echo ""
fi

# 进入项目目录
cd "$(dirname "$0")"
echo "当前目录: $(pwd)"
echo ""

# 获取依赖
echo "步骤 1/4: 获取Flutter依赖..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "错误: 获取依赖失败"
    exit 1
fi
echo "✓ 依赖获取成功"
echo ""

# 分析代码
echo "步骤 2/4: 分析代码..."
flutter analyze
if [ $? -ne 0 ]; then
    echo "警告: 代码分析发现问题，继续构建..."
fi
echo ""

# 构建APK
echo "步骤 3/4: 构建Release APK..."
flutter build apk --release

if [ $? -ne 0 ]; then
    echo ""
    echo "错误: APK构建失败"
    echo ""
    echo "常见问题:"
    echo "1. 检查Android SDK是否正确安装"
    echo "2. 检查ANDROID_SDK_ROOT环境变量"
    echo "3. 运行 'flutter doctor' 检查环境"
    exit 1
fi

echo ""
echo "✓ APK构建成功!"
echo ""

# 显示APK信息
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
    echo "APK文件: $APK_PATH"
    echo "文件大小: $APK_SIZE"
    echo ""
    
    # 复制到根目录方便查找
    cp "$APK_PATH" "./stock_analyzer_app.apk"
    echo "✓ 已复制到: ./stock_analyzer_app.apk"
fi

echo ""
echo "=========================================="
echo "  构建完成!"
echo "=========================================="
