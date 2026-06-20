@echo off
setlocal enabledelayedexpansion

:: ================================================
::  Personal Assistant - Build & Run Helper
::  Double-click to run; requires Flutter + JDK 17
:: ================================================

cd /d "%~dp0"

:: ==== Setup tool paths ====
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
echo   Personal Assistant - Dev Helper
echo ============================================
echo [1/3] Checking device connection...

adb devices 2>nul | findstr /r /c:"device$" >nul
if %errorlevel% neq 0 (
    echo [ERROR] No ADB device detected. Check USB debugging.
    pause & exit /b 1
)

echo.
echo Choose dev mode:
echo   [1] Hot Reload (recommended: edit code, press r to sync)
echo   [2] Fast Build (arm64 only, 60%% smaller)
echo   [3] Full Build (all ABIs + pub get + codegen)
echo.
set /p mode="Enter option [1-3]: "

if "%mode%"=="1" (
    echo.
    echo [2/3] Starting Flutter live debug...
    echo Once started, press [r] for hot reload, [R] for restart, [q] to quit.
    echo.
    call flutter run --debug
    exit /b 0
)

if "%mode%"=="2" (
    call :codegen
    goto :fast_build
)
call :codegen
goto :full_build

:: ==== Code generation ====
:codegen
echo.
echo [*] Running build_runner to regenerate Drift/DB code...
call dart run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo [WARN] Code generation failed. Attempting to continue...
)
exit /b 0

:: ==== Fast single-arch build ====
:fast_build
echo.
echo [2/3] Building arm64-only debug APK...
call flutter build apk --debug --target-platform android-arm64

set "APK=build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk"
if not exist "!APK!" (
    set "APK=build\app\outputs\flutter-apk\app-debug.apk"
)
goto :install

:: ==== Full build ====
:full_build
echo.
echo [1/4] Flutter pub get...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] flutter pub get failed
    pause & exit /b 1
)
echo [2/4] Building APK (debug, all ABIs)...
call flutter build apk --debug

set "APK=build\app\outputs\flutter-apk\app-debug.apk"
if not exist "!APK!" (
    echo [ERROR] Build failed.
    pause & exit /b 1
)
goto :install

:: ==== Install ====
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
echo [3/3] Installing to phone...
adb install -r -t "!APK!"
if %errorlevel% equ 0 (
    echo ============================================
    echo   INSTALL SUCCESS - Open app on phone!
    echo ============================================
) else (
    echo [ERROR] Install failed. Try manually:
    echo   adb install -r -t "!APK!"
)

pause
