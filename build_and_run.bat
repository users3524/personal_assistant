@echo off
setlocal enabledelayedexpansion

:: ================================================
::  Personal Assistant - 研发效能加速脚本
::  Double-click to run; requires Flutter + JDK 17
:: ================================================

cd /d "%~dp0"

:: ==== setup tool paths ====
set "FLUTTER_HOME=C:\Tools\Flutter\3.44.1"
set "JAVA_HOME=C:\Tools\Java\jdk-17.0.2"
set "ANDROID_SDK=C:\Tools\AndroidSDK"

if not exist "%FLUTTER_HOME%\bin\flutter.bat" (
    echo [ERROR] Flutter not found at %FLUTTER_HOME%
    pause & exit /b 1
)
if not exist "%JAVA_HOME%\bin\java.exe" (
    echo [ERROR] JDK 17 not found at %JAVA_HOME%
    pause & exit /b 1
)

set "PATH=%FLUTTER_HOME%\bin;%JAVA_HOME%\bin;%ANDROID_SDK%\platform-tools;%PATH%"

echo ============================================
echo   ⚡ 个人全能助手 研发效能加速脚本 ⚡
echo ============================================
echo [1/3] 检测设备连接状态...

adb devices 2>nul | findstr /r /c:"device$" >nul
if %errorlevel% neq 0 (
    echo [ERROR] 未检测到 ADB 连接的手机，请检查 USB 调试是否开启。
    pause & exit /b 1
)

echo.
echo [提示] 请选择你要进行的研发模式:
echo   [1] 实时热重载模式 (推荐：改动代码后在控制台按 'r' 秒级同步，不重装)
echo   [2] 快速单架构打包安装模式 (仅构建 arm64 架构，缩减 60%% 编译体积)
echo   [3] 全量构建安装 (兼容模式，所有架构 + pub get)
echo.
set /p mode="请输入选项 [1-3]: "

if "%mode%"=="1" (
    echo.
    echo [2/3] 正在启动 Flutter Live Debug...
    echo [提示] 启动成功后，修改代码直接在控制台输入 [r] 即可热重载！
    echo        输入 [R] 强制热重启，输入 [q] 退出。
    echo.
    call flutter run --debug
    exit /b 0
)

if "%mode%"=="2" goto :fast_build
goto :full_build

:: ==== 快速单架构打包安装模式 ====
:fast_build
echo.
echo [2/3] 正在生成单架构精简版测试 APK (仅 arm64-v8a)...
call flutter build apk --debug --target-platform android-arm64

set "APK=build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk"
if not exist "!APK!" (
    set "APK=build\app\outputs\flutter-apk\app-debug.apk"
)
goto :install

:: ==== 全量构建安装模式 ====
:full_build
echo.
echo [1/3] Flutter pub get...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] flutter pub get failed
    pause & exit /b 1
)
echo [2/3] Building APK (debug)...
call flutter build apk --debug

set "APK=build\app\outputs\flutter-apk\app-debug.apk"
if not exist "!APK!" (
    echo.
    echo [ERROR] Build failed.
    pause & exit /b 1
)
goto :install

:: ==== 安装 ====
:install
if not exist "!APK!" (
    for /r "build" %%f in (app-debug.apk) do set "APK=%%f"
)
if not exist "!APK!" (
    echo [ERROR] APK not found
    pause & exit /b 1
)
echo APK: !APK!

echo.
echo [3/3] 正在向手机推送并安装: !APK!
adb install -r -t "!APK!"
if %errorlevel% equ 0 (
    echo ============================================
    echo   ✅ 安装成功！请在手机上打开应用。
    echo ============================================
) else (
    echo [ERROR] 安装失败，请尝试手动执行: adb install -r -t "!APK!"
)

pause
