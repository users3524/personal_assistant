/// User preferences DAO — read/write app settings to database.
library;

import 'package:drift/drift.dart';
import 'dart:convert';

import '../ai/llm_strategy_config.dart';
import '../../../../core/database/app_database.dart';
import '../security/api_key_store.dart';

class UserPreferencesDao {
  final AppDatabase _db;
  final ApiKeyStore _apiKeyStore;

  UserPreferencesDao(this._db, {ApiKeyStore? apiKeyStore})
    : _apiKeyStore = apiKeyStore ?? SecureApiKeyStore();

  /// 获取或创建用户偏好（单例行，id=1）
  Future<UserPreference> getOrCreate() async {
    final existing = await (_db.select(
      _db.userPreferences,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (existing != null) return existing;

    await _db
        .into(_db.userPreferences)
        .insert(
          const UserPreferencesCompanion(id: Value(1)),
          mode: InsertMode.insertOrReplace,
        );
    return (await (_db.select(
      _db.userPreferences,
    )..where((t) => t.id.equals(1))).getSingle());
  }

  Future<String> getAiApiKey() async {
    final prefs = await getOrCreate();
    final secureKey = await _apiKeyStore.read();
    if (secureKey != null && secureKey.isNotEmpty) {
      return secureKey;
    }

    final legacyKey = prefs.aiApiKey?.trim() ?? '';
    if (legacyKey.isEmpty) {
      return '';
    }

    await _apiKeyStore.write(legacyKey);
    await _clearLegacyAiApiKey();
    return legacyKey;
  }

  /// 更新主题模式
  Future<void> setThemeMode(String mode) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(themeMode: Value(mode)),
    );
  }

  /// 更新 AI 配置
  Future<void> setAIConfig({
    required String provider,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    await getOrCreate();
    await _apiKeyStore.write(apiKey);
    final strategy = LLMStrategyConfig.fromLegacy(
      provider: provider,
      baseUrl: baseUrl,
      model: model,
    );
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(
        aiProvider: Value(provider),
        aiBaseUrl: Value(baseUrl),
        aiModel: Value(model),
        aiConfig: Value(strategy.toJsonString()),
        aiApiKey: const Value(null),
      ),
    );
  }

  Future<LLMStrategyConfig> getLLMStrategyConfig() async {
    final prefs = await getOrCreate();
    final rawConfig = prefs.aiConfig;
    if (rawConfig != null && rawConfig.trim().isNotEmpty) {
      try {
        return LLMStrategyConfig.fromJsonString(rawConfig);
      } catch (_) {
        // Fall through to legacy columns when the JSON is malformed.
      }
    }
    return LLMStrategyConfig.fromLegacy(
      provider: prefs.aiProvider,
      baseUrl: prefs.aiBaseUrl,
      model: prefs.aiModel,
    );
  }

  Future<void> setLLMStrategyConfig(LLMStrategyConfig config) async {
    await getOrCreate();
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(
        aiProvider: Value(config.provider),
        aiBaseUrl: Value(config.baseUrl),
        aiModel: Value(config.model),
        aiConfig: Value(config.toJsonString()),
        aiApiKey: const Value(null),
      ),
    );
  }

  Future<void> _clearLegacyAiApiKey() async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      const UserPreferencesCompanion(aiApiKey: Value(null)),
    );
  }

  /// 更新通知设置
  Future<void> setNotificationEnabled(bool enabled) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(notificationEnabled: Value(enabled)),
    );
  }

  /// 更新每日复盘提醒时间
  Future<void> setDailyReviewTime(String time) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(dailyReviewTime: Value(time)),
    );
  }

  /// 更新每周周报提醒开关
  Future<void> setWeeklyReminder(bool enabled) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(weeklyReportDay: Value(enabled ? 'sunday' : '')),
    );
  }

  /// 更新每周周报提醒时间
  Future<void> setWeeklyReportTime(String time) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(weeklyReportDay: Value(time)),
    );
  }

  /// 获取简历模板 ID
  Future<int> getResumeTemplateId() async {
    final prefs = await getOrCreate();
    return prefs.resumeTemplateId;
  }

  /// 保存简历模板 ID
  Future<void> setResumeTemplateId(int templateId) async {
    await getOrCreate();
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(resumeTemplateId: Value(templateId)),
    );
  }

  // ===== 待办分类持久化 =====

  /// 获取持久化的待办分类列表
  Future<List<String>> getTodoCategories() async {
    final prefs = await getOrCreate();
    final json = prefs.todoCategories;
    final list = (jsonDecode(json) as List).cast<String>();
    return list;
  }

  /// 保存待办分类列表
  Future<void> setTodoCategories(List<String> categories) async {
    await (_db.update(_db.userPreferences)..where((t) => t.id.equals(1))).write(
      UserPreferencesCompanion(todoCategories: Value(jsonEncode(categories))),
    );
  }
}
