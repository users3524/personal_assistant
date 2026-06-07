@echo off
cd /d D:\Code\personal_assistant
echo === 构建 APK ===
flutter build apk --debug
if errorlevel 1 exit /b 1
echo === 安装到手机 ===
C:\Tools\AndroidSDK\platform-tools\adb.exe install -r --bypass-low-target-sdk-block build\app\outputs\flutter-apk\app-debug.apk
echo === 完成！在手机上打开 App，然后 VSCode 按 F5（自动热重载）===
pause
