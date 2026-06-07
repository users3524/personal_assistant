@echo off
cd /d D:\Code\personal_assistant
echo === 构建 APK ===
flutter build apk --debug
if errorlevel 1 exit /b 1
echo === 安装到手机 ===
C:\Tools\AndroidSDK\platform-tools\adb.exe install -r --bypass-low-target-sdk-block build\app\outputs\flutter-apk\app-debug.apk
echo.
echo ============================================================
echo  APK 已安装！请在手机上打开 App，
echo  然后在终端运行: flutter attach
echo  （或 VSCode: Ctrl+Shift+P → Dart: Attach to Flutter）
echo  之后每次改代码 Ctrl+S 自动热重载，无需重新安装
echo ============================================================
pause
