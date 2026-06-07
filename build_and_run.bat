@echo off
cd /d D:\Code\personal_assistant
echo === Build APK ===
flutter build apk --debug
if errorlevel 1 exit /b 1
echo === Install to phone ===
C:\Tools\AndroidSDK\platform-tools\adb.exe install -r --bypass-low-target-sdk-block build\app\outputs\flutter-apk\app-debug.apk
echo.
echo =============================================
echo  DONE. Open app on phone, then run:
echo    flutter attach
echo  (Ctrl+S in VSCode for hot reload)
echo =============================================
pause
