@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

:: ==== Setup tool paths ====
set "FLUTTER_HOME=C:\Tools\Flutter\3.44.1"
set "JAVA_HOME=C:\Tools\Java\jdk-17.0.2"
set "ANDROID_SDK=C:\Tools\AndroidSDK"

:: Optional: pass a device id as the first argument, or set DEVICE_ID before running.
if not defined DEVICE_ID set "DEVICE_ID=%~1"
:: Optional: pass a mode as the second argument, or set MODE before running.
if not defined MODE set "MODE=%~2"

set "ANDROID_HOME=%ANDROID_SDK%"
set "ANDROID_SDK_ROOT=%ANDROID_SDK%"
set "PATH=%FLUTTER_HOME%\bin;%JAVA_HOME%\bin;%ANDROID_SDK%\platform-tools;%ANDROID_SDK%\cmdline-tools\latest\bin;%PATH%"

echo ============================================
echo    Personal Assistant - Dev SpeedUp Script
echo ============================================
echo [1/4] Checking Android device...

call :select_device
if errorlevel 1 (
    pause
    exit /b 1
)

echo [INFO] Using device: %DEVICE_ID% (%DEVICE_MODEL%)

echo.
echo [2/4] Preparing device for Flutter debugging...
call :prepare_device
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo Choose dev mode:
echo   [1] Live Hot Reload   (Flutter run on selected device)
echo   [2] Fast Build        (Build arm64-only APK + install)
echo   [3] Full Reset Build  (Clean + pub get + codegen + all ABIs)
echo.
if not defined MODE set /p MODE="Enter option [1-3]: "

if "%MODE%"=="1" (
    echo.
    echo [3/4] Running codegen to sync DB schema...
    call :codegen
    if errorlevel 1 (
        pause
        exit /b 1
    )

    echo.
    echo [4/4] Launching Flutter live debug window...
    echo -----------------------------------------------------------
    echo Press r to hot reload, R to restart, q to quit.
    echo -----------------------------------------------------------
    echo.

    start "Flutter_Live_Debug" cmd /k flutter run -d "%DEVICE_ID%" --debug
    exit /b 0
)

if "%MODE%"=="2" (
    call :codegen
    if errorlevel 1 (
        pause
        exit /b 1
    )
    goto :fast_build
)

if "%MODE%"=="3" (
    echo [*] Executing full project clean...
    call flutter clean
    if errorlevel 1 (
        pause
        exit /b 1
    )
    call flutter pub get
    if errorlevel 1 (
        pause
        exit /b 1
    )
    call :codegen
    if errorlevel 1 (
        pause
        exit /b 1
    )
    goto :full_build
)

echo [ERROR] Unknown option: %MODE%
pause
exit /b 1

:: ==== Device selection ====
:select_device
where adb >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb was not found. Check ANDROID_SDK in this script.
    exit /b 1
)

if defined DEVICE_ID (
    adb -s "%DEVICE_ID%" get-state 1>nul 2>nul
    if errorlevel 1 (
        echo [ERROR] Device %DEVICE_ID% is not available over ADB.
        exit /b 1
    )
    call :read_device_model
    exit /b 0
)

for /f "tokens=1" %%d in ('adb devices -l ^| findstr /r /c:"device .*model:NX741J"') do (
    if not defined DEVICE_ID set "DEVICE_ID=%%d"
)

if not defined DEVICE_ID (
    for /f "tokens=1" %%d in ('adb devices ^| findstr /r /c:"device$"') do (
        if not defined DEVICE_ID set "DEVICE_ID=%%d"
    )
)

if not defined DEVICE_ID (
    echo [ERROR] No ADB device detected. Check USB debugging and authorization.
    exit /b 1
)

call :read_device_model
exit /b 0

:read_device_model
set "DEVICE_MODEL=unknown"
for /f "delims=" %%m in ('adb -s "%DEVICE_ID%" shell getprop ro.product.model 2^>nul') do (
    if not "%%m"=="" set "DEVICE_MODEL=%%m"
)
exit /b 0

:: ==== NX741J / Android 16 debug preparation ====
:prepare_device
:: Some NX741J builds set global log.tag=S, which hides the line Flutter uses
:: to discover "The Dart VM service is listening on ...".
adb -s "%DEVICE_ID%" shell setprop log.tag.flutter V >nul 2>&1
adb -s "%DEVICE_ID%" shell setprop log.tag.Flutter V >nul 2>&1
adb -s "%DEVICE_ID%" shell setprop log.tag.DartVM V >nul 2>&1

set "FLUTTER_LOG_TAG="
for /f "delims=" %%v in ('adb -s "%DEVICE_ID%" shell getprop log.tag.flutter 2^>nul') do (
    set "FLUTTER_LOG_TAG=%%v"
)

if /i not "%FLUTTER_LOG_TAG%"=="V" (
    echo [WARN] Could not enable log.tag.flutter. Flutter may hang waiting for VM Service.
) else (
    echo [OK] Flutter VM Service log tag enabled.
)

exit /b 0

:: ==== Code generation ====
:codegen
echo.
echo [*] Running build_runner to regenerate Drift/DB code...
call dart run build_runner build
if errorlevel 1 exit /b %errorlevel%
exit /b 0

:: ==== Fast single-arch build ====
:fast_build
echo.
echo [3/4] Building arm64-only debug APK...
call flutter build apk --debug --target-platform android-arm64
if errorlevel 1 (
    pause
    exit /b 1
)
set "APK=build\app\outputs\flutter-apk\app-arm64-v8a-debug.apk"
if not exist "!APK!" set "APK=build\app\outputs\flutter-apk\app-debug.apk"
goto :install

:: ==== Full build ====
:full_build
echo.
echo [3/4] Building APK (debug, all ABIs)...
call flutter build apk --debug
if errorlevel 1 (
    pause
    exit /b 1
)
set "APK=build\app\outputs\flutter-apk\app-debug.apk"
goto :install

:: ==== Install ====
:install
if not exist "!APK!" (
    for /r "build" %%f in (app-debug.apk) do set "APK=%%f"
)
if not exist "!APK!" (
    echo [ERROR] APK not found.
    pause
    exit /b 1
)
echo APK Target: !APK!
echo [4/4] Installing to %DEVICE_ID%...
adb -s "%DEVICE_ID%" install -r -t "!APK!"
pause
