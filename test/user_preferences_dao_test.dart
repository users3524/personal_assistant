import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/llm_strategy_config.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/core/database/user_preferences_dao.dart';
import 'package:personal_assistant/core/security/api_key_store.dart';

void main() {
  group('UserPreferencesDao', () {
    late AppDatabase db;
    late InMemoryApiKeyStore apiKeyStore;
    late UserPreferencesDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      apiKeyStore = InMemoryApiKeyStore();
      dao = UserPreferencesDao(db, apiKeyStore: apiKeyStore);
    });

    tearDown(() async {
      await db.close();
    });

    test('stores AI API key outside user_preferences', () async {
      await dao.getOrCreate();

      await dao.setAIConfig(
        provider: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        apiKey: 'new-secret-key',
      );

      final prefs = await dao.getOrCreate();
      expect(prefs.aiProvider, 'OpenAI');
      expect(prefs.aiApiKey, null);
      expect(await apiKeyStore.read(), 'new-secret-key');
      expect(await dao.getAiApiKey(), 'new-secret-key');
    });

    test('migrates legacy plaintext key and clears database column', () async {
      final now = DateTime(2026, 6, 20);
      await db
          .into(db.userPreferences)
          .insert(
            UserPreferencesCompanion.insert(
              id: const Value(1),
              aiApiKey: const Value('legacy-secret-key'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );

      expect(await dao.getAiApiKey(), 'legacy-secret-key');
      final prefs = await dao.getOrCreate();
      expect(prefs.aiApiKey, null);
      expect(await apiKeyStore.read(), 'legacy-secret-key');
    });

    test('stores resume template id', () async {
      expect(await dao.getResumeTemplateId(), 0);

      await dao.setResumeTemplateId(2);

      final prefs = await dao.getOrCreate();
      expect(prefs.resumeTemplateId, 2);
      expect(await dao.getResumeTemplateId(), 2);
    });

    test('stores non-sensitive LLM strategy config as JSON', () async {
      const config = LLMStrategyConfig(
        provider: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        dailyReviewMaxTokens: 600,
        weeklyReportMaxTokens: 1400,
        chatMaxTokens: 900,
        promptBudgetChars: 10000,
      );

      await dao.setLLMStrategyConfig(config);

      final prefs = await dao.getOrCreate();
      final restored = await dao.getLLMStrategyConfig();

      expect(prefs.aiConfig, contains('"provider":"OpenAI"'));
      expect(prefs.aiConfig, isNot(contains('apiKey')));
      expect(restored.provider, config.provider);
      expect(restored.baseUrl, config.baseUrl);
      expect(restored.model, config.model);
      expect(restored.dailyReviewMaxTokens, 600);
      expect(restored.promptBudgetChars, 10000);
    });

    test('falls back to legacy AI columns when JSON is absent', () async {
      await dao.setAIConfig(
        provider: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'secret-key',
      );

      await (db.update(db.userPreferences)..where((t) => t.id.equals(1))).write(
        const UserPreferencesCompanion(aiConfig: Value(null)),
      );

      final config = await dao.getLLMStrategyConfig();

      expect(config.provider, 'DeepSeek');
      expect(config.baseUrl, 'https://api.deepseek.com');
      expect(config.model, 'deepseek-chat');
      expect(await dao.getAiApiKey(), 'secret-key');
    });
  });
}
