/// AI 服务 Provider — 从用户偏好读取配置并创建 AIService 实例。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_service.dart';
import '../../core/ai/llm_strategy_config.dart';
import '../../core/ai/openai_service.dart';
import '../../core/ai/offline_review_generator.dart';
import '../database/app_database_provider.dart';
import '../database/user_preferences_dao.dart';

/// AI 配置状态（内存中保持，启动时从数据库加载）
class AIConfig {
  final String provider;
  final String baseUrl;
  final String model;
  final String apiKey;
  final LLMStrategyConfig strategy;

  const AIConfig({
    this.provider = LLMStrategyConfig.offlineProvider,
    this.baseUrl = '',
    this.model = '',
    this.apiKey = '',
    this.strategy = const LLMStrategyConfig(),
  });

  AIConfig copyWith({
    String? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
    LLMStrategyConfig? strategy,
  }) => AIConfig(
    provider: provider ?? this.provider,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    apiKey: apiKey ?? this.apiKey,
    strategy: strategy ?? this.strategy,
  );

  /// 是否已配置可用的 AI 服务
  bool get isConfigured =>
      provider == LLMStrategyConfig.offlineProvider || apiKey.isNotEmpty;
}

/// AI 配置 Provider（可读写，启动时自动加载数据库配置）
final aiConfigProvider = StateNotifierProvider<AIConfigNotifier, AIConfig>((
  ref,
) {
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
      final strategy = await dao.getLLMStrategyConfig();
      final apiKey = await dao.getAiApiKey();
      state = AIConfig(
        provider: strategy.provider,
        baseUrl: strategy.baseUrl,
        model: strategy.model,
        apiKey: apiKey,
        strategy: strategy,
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
    LLMStrategyConfig? strategy,
  }) {
    state = state.copyWith(
      provider: provider,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      strategy: strategy,
    );
  }
}

/// AI 服务 Provider（跟随配置变化自动重建）
final aiServiceProvider = Provider<AIService?>((ref) {
  final config = ref.watch(aiConfigProvider);
  if (!config.isConfigured) return null;

  // 离线模式：使用模板引擎生成，无需网络和 API Key
  if (config.provider == LLMStrategyConfig.offlineProvider) {
    return OfflineReviewGenerator();
  }

  return OpenAIService(
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    model: config.model,
  );
});
