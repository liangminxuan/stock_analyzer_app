@echo off
chcp 65001 >nul
title 股票分析助手APP - 编译工具

echo ==========================================
echo   股票分析助手APP - 编译工具
echo ==========================================
echo.

:: 设置项目路径
set "PROJECT_PATH=D:\soft\stock_analyzer_app"

:: 检查项目目录
if not exist "%PROJECT_PATH%" (
    echo 错误: 未找到项目目录 %PROJECT_PATH%
    echo 请确认项目路径是否正确
    pause
    exit /b 1
)

cd /d "%PROJECT_PATH%"
echo 当前目录: %CD%
echo.

:: 检查Flutter
where flutter >nul 2>&1
if %errorLevel% neq 0 (
    echo 错误: 未找到Flutter命令
    echo.
    echo 请先运行 setup_windows.bat 安装环境
    echo 或者手动将 C:\flutter\bin 添加到PATH
    pause
    exit /b 1
)

echo [OK] Flutter已找到
flutter --version
echo.

:: 设置国内镜像
echo 设置国内镜像加速...
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
echo [OK] 镜像设置完成
echo.

:: 步骤1: 清理旧构建
echo [1/5] 清理旧构建...
flutter clean
if %errorLevel% neq 0 (
    echo [警告] 清理失败，继续编译...
)
echo [OK] 清理完成
echo.

:: 步骤2: 获取依赖
echo [2/5] 获取Flutter依赖...
flutter pub get
if %errorLevel% neq 0 (
    echo 错误: 获取依赖失败
    echo.
    echo 可能的解决方案:
    echo 1. 检查网络连接
    echo 2. 尝试设置代理
    echo 3. 手动运行: flutter pub get --verbose
    pause
    exit /b 1
)
echo [OK] 依赖获取完成
echo.

:: 步骤3: 分析代码
echo [3/5] 分析代码...
flutter analyze
if %errorLevel% neq 0 (
    echo [警告] 代码分析发现问题，继续编译...
) else (
    echo [OK] 代码分析通过
)
echo.

:: 步骤4: 运行测试
echo [4/5] 运行测试...
flutter test
if %errorLevel% neq 0 (
    echo [警告] 测试未通过，继续编译...
) else (
    echo [OK] 测试通过
)
echo.

:: 步骤5: 构建APK
echo [5/5] 构建Release APK...
echo 这可能需要几分钟时间，请耐心等待...
echo.

flutter build apk --release --verbose

if %errorLevel% neq 0 (
    echo.
    echo ==========================================
    echo   错误: APK构建失败
    echo ==========================================
    echo.
    echo 常见问题及解决方案:
    echo.
    echo 1. Android SDK未找到
    echo    解决方案: 安装Android Studio或设置ANDROID_SDK_ROOT环境变量
    echo.
    echo 2. 缺少Android许可证
    echo    解决方案: 运行 flutter doctor --android-licenses 并接受所有许可证
    echo.
    echo 3. 内存不足
    echo    解决方案: 关闭其他程序，或增加虚拟内存
    echo.
    echo 4. 网络问题
    echo    解决方案: 检查网络连接，或设置代理
    echo.
    echo 运行诊断命令查看详细信息:
    echo   flutter doctor -v
    echo.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   APK构建成功!
echo ==========================================
echo.

:: 查找APK文件
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"

if exist "%APK_PATH%" (
    echo APK文件: %CD%\%APK_PATH%
    
    :: 获取文件大小
    for %%I in ("%APK_PATH%") do (
        echo 文件大小: %%~zI 字节
    )
    
    :: 复制到根目录
    copy "%APK_PATH%" "stock_analyzer_app.apk" >nul
    echo.
    echo [OK] 已复制到: %CD%\stock_analyzer_app.apk
    
    echo.
    echo 安装方法:
    echo 1. 将APK文件传输到手机
    echo 2. 在手机上点击安装
    echo 3. 如提示"未知来源"，请在设置中允许
    echo.
    echo 或使用ADB安装:
    echo   adb install stock_analyzer_app.apk
) else (
    echo [警告] 未找到APK文件，请检查 build\app\outputs\flutter-apk\ 目录
)

echo.
pause
