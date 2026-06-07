@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ============================================
::  个人全能助手 — 构建并安装 APK 到手机
::  使用方式：双击运行此文件
:: ============================================

:: 检测依赖工具
echo [1/4] 检测开发环境...

:: Flutter
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    if exist "C:\Tools\Flutter\3.44.1\bin\flutter.bat" (
        set "PATH=C:\Tools\Flutter\3.44.1\bin;%PATH%"
    ) else (
        echo [错误] 未找到 Flutter，请安装 Flutter SDK
        echo   下载地址：https://flutter.dev
        pause
        exit /b 1
    )
)

:: Java
where java >nul 2>&1
if %errorlevel% neq 0 (
    if exist "C:\Tools\Java\jdk-17.0.2\bin\java.exe" (
        set "JAVA_HOME=C:\Tools\Java\jdk-17.0.2"
        set "PATH=%JAVA_HOME%\bin;%PATH%"
    ) else (
        echo [警告] 未检测到 Java，将尝试使用系统默认 Java
    )
)

:: ADB
where adb >nul 2>&1
if %errorlevel% neq 0 (
    if exist "C:\Tools\AndroidSDK\platform-tools\adb.exe" (
        set "PATH=C:\Tools\AndroidSDK\platform-tools;%PATH%"
    ) else (
        echo [警告] 未找到 ADB，安装步骤将被跳过
        set "NO_ADB=1"
    )
)

:: 进入项目目录
cd /d "%~dp0"
if %errorlevel% neq 0 (
    echo [错误] 无法进入项目目录
    pause
    exit /b 1
)

echo [2/4] 获取依赖...
call flutter pub get
if %errorlevel% neq 0 (
    echo [错误] 依赖获取失败
    pause
    exit /b 1
)

echo [3/4] 构建 APK（Debug 模式）...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo [错误] 构建失败，请检查上方错误信息。
    echo 常见问题：
    echo   1. Android SDK 未安装或不兼容
    echo   2. 网络问题导致依赖下载失败
    echo   3. JDK 版本不匹配（需要 JDK 17）
    echo.
    pause
    exit /b 1
)

:: 检测 APK 输出路径
set "APK_PATH=build\app\outputs\flutter-apk\app-debug.apk"
if not exist "%APK_PATH%" (
    echo [警告] 未在默认路径找到 APK，正在搜索...
    for /r "build" %%f in (app-debug.apk) do set "APK_PATH=%%f"
    if not exist "!APK_PATH!" (
        echo [错误] 找不到构建输出的 APK 文件
        pause
        exit /b 1
    )
)

echo [4/4] 安装到手机...
if "%NO_ADB%"=="1" (
    echo [跳过] ADB 不可用，请手动安装 APK：
    echo   %APK_PATH%
) else (
    :: 检查设备连接
    adb devices 2>nul | findstr /r "device$" >nul
    if %errorlevel% neq 0 (
        echo [警告] 未检测到已连接的 Android 设备
        echo   请确保：
        echo   1. 手机已通过 USB 连接电脑
        echo   2. 手机已开启「USB 调试」模式
        echo   3. 已授权此电脑的调试请求
        echo.
        echo APK 已构建完成，路径：
        echo   %APK_PATH%
        echo.
        echo 手动安装方式：
        echo   1. 将 APK 复制到手机
        echo   2. 在手机上打开并安装
    ) else (
        echo 正在安装...
        adb install -r "%APK_PATH%"
        if %errorlevel% equ 0 (
            echo.
            echo ============================================
            echo  安装成功！在手机上打开「个人全能助手」
            echo ============================================
        ) else (
            echo [错误] 安装失败，请检查：
            echo   1. 手机存储空间是否充足
            echo   2. 是否已卸载旧版本
            echo   3. 手机是否允许安装未知来源应用
        )
    )
)

echo.
pause
