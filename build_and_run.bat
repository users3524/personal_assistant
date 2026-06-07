@echo off
setlocal enabledelayedexpansion

:: ================================================
::  Personal Assistant - Build and Install APK
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

:: ==== step 1: pub get ====
echo [1/3] Flutter pub get...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] flutter pub get failed
    pause & exit /b 1
)

:: ==== step 2: build ====
echo [2/3] Building APK (debug)...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed.
    pause & exit /b 1
)

:: ==== step 3: install ====
echo [3/3] Installing to phone...

:: find APK
set "APK=build\app\outputs\flutter-apk\app-debug.apk"
if not exist "!APK!" (
    for /r "build" %%f in (app-debug.apk) do set "APK=%%f"
)
if not exist "!APK!" (
    echo [ERROR] APK not found
    pause & exit /b 1
)
echo APK: !APK!

:: check adb + device
where adb >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo [WARN] adb not found in:
    echo   %ANDROID_SDK%\platform-tools
    echo.
    echo APK is at: !APK!
    echo Copy it to your phone and install manually.
    echo.
    pause & exit /b 0
)

:: check device connected
adb devices 2>nul | findstr /r /c:"device$" >nul
if %errorlevel% neq 0 (
    echo.
    echo [WARN] No device connected via ADB.
    echo.
    echo APK is at: !APK!
    echo Copy it to your phone and install manually.
    echo.
    pause & exit /b 0
)

:: install
echo Installing...
adb install -r "!APK!"
if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo   INSTALL SUCCESS - Open app on your phone
    echo ============================================
) else (
    echo.
    echo [ERROR] Install failed - try:
    echo   adb install -r "!APK!"
)

pause
