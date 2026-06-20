@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

:: ==== Setup tool paths ====
set "FLUTTER_HOME=C:\Tools\Flutter\3.44.1"
set "JAVA_HOME=C:\Tools\Java\jdk-17.0.2"
set "ANDROID_SDK=C:\Tools\AndroidSDK"

set "PATH=%FLUTTER_HOME%\bin;%JAVA_HOME%\bin;%ANDROID_SDK%\platform-tools;%PATH%"

echo ============================================
echo   Personal Assistant - Dev SpeedUp
echo ============================================
echo [1/3] Checking device connection...

adb devices 2>nul | findstr /r /c:"device$" >nul
if %errorlevel% neq 0 (
    echo [ERROR] No ADB device detected. Check USB debugging.
    pause & exit /b 1
)

echo.
echo Choose dev mode:
echo   [1] Live Hot Reload   (DIRECT RUN - unlocked keyboard, arm64 only)
echo   [2] Fast Build        (Build arm64-only APK + install)
echo   [3] Full Reset Build  (flutter clean + pub get + codegen + all ABIs)
echo.
set /p mode="Enter option [1-3]: "

if "%mode%"=="1" (
    echo.
    echo [2/3] Starting Flutter live debug...
    echo -----------------------------------------------------------
    echo Press [r] to hot reload, [R] to restart, [q] to quit.
    echo Keyboard input is fully unlocked (no call keyword).
    echo -----------------------------------------------------------
    echo.
    flutter run --debug --target-platform android-arm64
    exit /b 0
)

if "%mode%"=="2" (
    call :codegen
    goto :fast_build
)
if "%mode%"=="3" (
    echo [*] Executing Full Project Purge...
    call flutter clean
    call flutter pub get
    call :codegen
    goto :full_build
)
exit /b 0

:: ==== Code generation ====
:codegen
echo.
echo [*] Running build_runner to regenerate Drift/DB code...
call dart run build_runner build --delete-conflicting-outputs
exit /b 0

:: ==== Fast single-arch build ====
:fast_build
echo.
echo [2/3] Building arm64-only debug APK...
call flutter build apk --debug --target-platform android-arm64
set "APK=build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk"
if not exist "!APK!" set "APK=build\app\outputs\flutter-apk\app-debug.apk"
goto :install

:: ==== Full build ====
:full_build
echo.
echo [2/4] Building APK (debug, all ABIs)...
call flutter build apk --debug
set "APK=build\app\outputs\flutter-apk\app-debug.apk"
goto :install

:: ==== Install ====
:install
if not exist "!APK!" (
    for /r "build" %%f in (app-debug.apk) do set "APK=%%f"
)
echo APK Target: !APK!
echo [3/3] Installing to phone...
adb install -r -t "!APK!"
pause
