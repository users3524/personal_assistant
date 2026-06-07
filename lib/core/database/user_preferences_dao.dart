/// User preferences DAO — read/write app settings to database.
library;

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

class UserPreferencesDao {
  final AppDatabase _db;

  UserPreferencesDao(this._db);

  /// 获取或创建用户偏好（单例行，id=1）
  Future<UserPreference> getOrCreate() async {
    final existing = await (_db.select(_db.userPreferences)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (existing != null) return existing;

    await _db.into(_db.userPreferences).insert(
          UserPreferencesCompanion(id: const Value(1)),
          mode: InsertMode.insertOrReplace,
        );
    return (await (_db.select(_db.userPreferences)
          ..where((t) => t.id.equals(1)))
        .getSingle());
  }

  /// 更新主题模式
  Future<void> setThemeMode(String mode) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1)))
        .write(UserPreferencesCompanion(themeMode: Value(mode)));
  }

  /// 更新 AI 配置
  Future<void> setAIConfig({
    required String provider,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1)))
        .write(UserPreferencesCompanion(
      aiProvider: Value(provider),
      aiBaseUrl: Value(baseUrl),
      aiModel: Value(model),
      aiApiKey: Value(apiKey),
    ));
  }

  /// 更新通知设置
  Future<void> setNotificationEnabled(bool enabled) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1)))
        .write(UserPreferencesCompanion(notificationEnabled: Value(enabled)));
  }

  /// 更新每日复盘提醒时间
  Future<void> setDailyReviewTime(String time) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1)))
        .write(UserPreferencesCompanion(dailyReviewTime: Value(time)));
  }
}
