@echo off
setlocal enabledelayedexpansion

:: ================================================
::  Personal Assistant - Build and Install APK
::  Double-click to run; requires Flutter + JDK 17
:: ================================================

cd /d "%~dp0"

:: ---- step 1: find Flutter ----
set "FLUTTER="
where flutter >nul 2>nul
if %errorlevel% equ 0 set "FLUTTER=flutter"

if defined FLUTTER goto :found_flutter
if exist "C:\Tools\Flutter\3.44.1\bin\flutter.bat" (
    set "PATH=C:\Tools\Flutter\3.44.1\bin;%PATH%"
    set "FLUTTER=flutter"
)
if defined FLUTTER goto :found_flutter

echo [ERROR] Flutter not found. Install Flutter SDK first.
echo    Download: https://flutter.dev
pause
exit /b 1

:found_flutter
echo [1/4] Flutter OK

:: ---- step 2: find Java ----
java -version >nul 2>nul
if %errorlevel% equ 0 goto :found_java
if exist "C:\Tools\Java\jdk-17.0.2\bin\java.exe" (
    set "JAVA_HOME=C:\Tools\Java\jdk-17.0.2"
    set "PATH=!JAVA_HOME!\bin;!PATH!"
)
java -version >nul 2>nul
if %errorlevel% equ 0 goto :found_java
echo [WARN] Java not detected. Build may fail.

:found_java
echo [2/4] Java OK

:: ---- step 3: pub get ----
echo [3/4] Running flutter pub get...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] flutter pub get failed
    pause
    exit /b 1
)

:: ---- step 4: build ----
echo [4/4] Building APK (debug)...
call flutter build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed. Common causes:
    echo   1. Android SDK missing or incompatible
    echo   2. Network issue during dependency download
    echo   3. JDK version mismatch (JDK 17 required)
    echo.
    pause
    exit /b 1
)

:: ---- locate APK ----
set "APK=build\app\outputs\flutter-apk\app-debug.apk"
if not exist "!APK!" (
    for /r "build" %%f in (app-debug.apk) do set "APK=%%f"
)
if not exist "!APK!" (
    echo [ERROR] APK not found in build output
    pause
    exit /b 1
)
echo APK: !APK!

:: ---- install ----
echo.
echo === Installing to phone ===
adb devices 2>nul | findstr "device$" >nul
if %errorlevel% neq 0 (
    echo [WARN] No Android device detected via ADB.
    echo.
    echo Make sure:
    echo   1. Phone connected via USB
    echo   2. USB Debugging enabled on phone
    echo   3. This PC is authorized for debugging
    echo.
    echo The APK is ready at:
    echo   !APK!
    echo.
    echo To install manually:
    echo   1. Copy the APK to your phone
    echo   2. Open the APK file on your phone to install
    echo.
    pause
    exit /b 0
)

adb install -r "!APK!"
if %errorlevel% equ 0 (
    echo.
    echo ============================================
    echo   INSTALL SUCCESS - Open app on your phone
    echo ============================================
) else (
    echo [ERROR] Install failed. Check:
    echo   1. Phone storage space
    echo   2. Uninstall old version first
    echo   3. Allow install from unknown sources
)

echo.
pause
