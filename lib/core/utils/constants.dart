/// 应用全局常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = '个人全能助手';
  static const String appNameEn = 'Personal Assistant';

  /// 数据库
  static const String databaseName = 'personal_assistant.db';

  /// 版本
  static const String appVersion = '1.0.0';
  static const int databaseVersion = 1;

  /// 通知
  static const String dailyReviewDefaultTime = '21:00';
  static const String weeklyReportDefaultDay = 'sunday';
  static const int defaultNotificationId = 1000;

  /// 备份
  static const int backupVersion = 1;
  static const int pbkdf2Iterations = 10000;
  static const int aesKeyLength = 32; // 256-bit
}
