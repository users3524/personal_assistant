/// AI 服务 Provider — 从用户偏好读取配置并创建 AIService 实例。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_service.dart';
import '../../core/ai/openai_service.dart';
import '../database/app_database_provider.dart';
import '../database/user_preferences_dao.dart';

/// AI 配置状态（内存中保持，启动时从数据库加载）
class AIConfig {
  final String provider;
  final String baseUrl;
  final String model;
  final String apiKey;

  const AIConfig({
    this.provider = 'OpenAI',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    this.apiKey = '',
  });

  AIConfig copyWith({
    String? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
  }) =>
      AIConfig(
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
      );

  bool get isConfigured => apiKey.isNotEmpty;
}

/// AI 配置 Provider（可读写，启动时自动加载数据库配置）
final aiConfigProvider = StateNotifierProvider<AIConfigNotifier, AIConfig>((ref) {
  final notifier = AIConfigNotifier(ref);
  // 异步从数据库加载配置
  Future.microtask(() => notifier.loadFromDb());
  return notifier;
});

class AIConfigNotifier extends StateNotifier<AIConfig> {
  final Ref _ref;
  bool _loaded = false;

  AIConfigNotifier(this._ref) : super(const AIConfig());

  Future<void> loadFromDb() async {
    if (_loaded) return;
    try {
      final db = await _ref.read(appDatabaseProvider.future);
      final dao = UserPreferencesDao(db);
      final prefs = await dao.getOrCreate();
      state = AIConfig(
        provider: prefs.aiProvider,
        baseUrl: prefs.aiBaseUrl ?? 'https://api.openai.com/v1',
        model: prefs.aiModel ?? 'gpt-4o-mini',
        apiKey: prefs.aiApiKey ?? '',
      );
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  void update({
    String? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
  }) {
    state = state.copyWith(
      provider: provider,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
    );
  }
}

/// AI 服务 Provider（跟随配置变化自动重建）
final aiServiceProvider = Provider<AIService?>((ref) {
  final config = ref.watch(aiConfigProvider);
  if (!config.isConfigured) return null;
  return OpenAIService(
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    model: config.model,
  );
});
