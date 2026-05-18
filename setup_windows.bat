@echo off
chcp 65001 >nul
title 股票分析助手APP - Windows环境搭建与编译

echo ==========================================
echo   股票分析助手APP - Windows环境搭建
echo ==========================================
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 错误: 请以管理员身份运行此脚本!
    echo 右键点击脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo [1/6] 检查系统环境...
echo.

:: 检查Git
where git >nul 2>&1
if %errorLevel% neq 0 (
    echo Git未安装，正在下载安装...
    powershell -Command "& {Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe' -OutFile 'C:\temp\git-installer.exe'}"
    echo 请安装Git后重新运行此脚本
    C:\temp\git-installer.exe
    pause
    exit /b 1
)
echo [OK] Git已安装

:: 检查Java
java -version >nul 2>&1
if %errorLevel% neq 0 (
    echo Java未安装，正在下载OpenJDK...
    if not exist "C:\Program Files\Java" mkdir "C:\Program Files\Java"
    powershell -Command "& {Invoke-WebRequest -Uri 'https://download.java.net/openjdk/jdk17/ri/openjdk-17+35_windows-x64_bin.zip' -OutFile 'C:\temp\jdk.zip'}"
    powershell -Command "& {Expand-Archive -Path 'C:\temp\jdk.zip' -DestinationPath 'C:\Program Files\Java'}"
    setx JAVA_HOME "C:\Program Files\Java\jdk-17" /M
    setx PATH "%PATH%;%%JAVA_HOME%%\bin" /M
    echo [OK] Java已安装
) else (
    echo [OK] Java已安装
)

echo.
echo [2/6] 下载Flutter SDK...
echo.

if not exist "C:\flutter" (
    echo 正在下载Flutter SDK（国内镜像）...
    cd C:\
    git clone https://gitee.com/mirrors/Flutter.git flutter -b stable --depth 1
    if %errorLevel% neq 0 (
        echo 国内镜像失败，尝试官方源...
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
    )
    echo [OK] Flutter SDK下载完成
) else (
    echo [OK] Flutter SDK已存在
)

echo.
echo [3/6] 配置环境变量...
echo.

:: 添加Flutter到PATH
setx PATH "C:\flutter\bin;%PATH%" /M
setx PUB_HOSTED_URL "https://pub.flutter-io.cn" /M
setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn" /M
setx ANDROID_SDK_ROOT "C:\Users\%USERNAME%\AppData\Local\Android\Sdk" /M

echo [OK] 环境变量配置完成

echo.
echo [4/6] 下载Android SDK...
echo.

if not exist "C:\Users\%USERNAME%\AppData\Local\Android\Sdk" (
    echo 正在下载Android命令行工具...
    if not exist "C:\Android" mkdir C:\Android
    cd C:\Android
    
    powershell -Command "& {Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile 'cmdline-tools.zip'}"
    
    echo 解压Android SDK...
    powershell -Command "& {Expand-Archive -Path 'cmdline-tools.zip' -DestinationPath 'C:\Android'}"
    
    mkdir "C:\Users\%USERNAME%\AppData\Local\Android\Sdk"
    xcopy /E /I "C:\Android\cmdline-tools" "C:\Users\%USERNAME%\AppData\Local\Android\Sdk\cmdline-tools"
    
    echo [OK] Android SDK下载完成
) else (
    echo [OK] Android SDK已存在
)

echo.
echo [5/6] 安装Android SDK组件...
echo.

set "SDKMANAGER=C:\Users\%USERNAME%\AppData\Local\Android\Sdk\cmdline-tools\bin\sdkmanager.bat"
if exist "%SDKMANAGER%" (
    echo 安装必要组件...
    call "%SDKMANAGER%" --sdk_root="C:\Users\%USERNAME%\AppData\Local\Android\Sdk" "platform-tools" "platforms;android-33" "build-tools;33.0.0" --channel=0
    echo [OK] Android SDK组件安装完成
) else (
    echo [警告] 未找到sdkmanager，请手动安装Android Studio
)

echo.
echo [6/6] 验证Flutter环境...
echo.

:: 重新加载环境变量
set "PATH=C:\flutter\bin;%PATH%"

cd C:\flutter
flutter doctor

echo.
echo ==========================================
echo   环境搭建完成！
echo ==========================================
echo.
echo 请按以下步骤操作：
echo 1. 关闭并重新打开命令提示符
echo 2. 进入项目目录: cd D:\soft\stock_analyzer_app
echo 3. 运行编译脚本: compile.bat
echo.
pause
