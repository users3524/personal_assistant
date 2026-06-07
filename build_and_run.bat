@echo off
cd /d D:\Code\personal_assistant

:: set tool paths
set "FLUTTER_HOME=C:\Tools\Flutter\3.44.1"
set "ANDROID_SDK=C:\Tools\AndroidSDK"
set "JAVA_HOME=C:\Tools\Java\jdk-17.0.2"
set "PATH=%FLUTTER_HOME%\bin;%ANDROID_SDK%\platform-tools;%JAVA_HOME%\bin;%PATH%"

echo === Build APK ===
flutter build apk --debug
if errorlevel 1 (
    echo Build failed.
    pause
    exit /b 1
)

echo === Install to phone ===
adb install -r --bypass-low-target-sdk-block build\app\outputs\flutter-apk\app-debug.apk
echo.
echo =============================================
echo  DONE. Open app on phone, then run in terminal:
echo    flutter attach
echo =============================================
pause
