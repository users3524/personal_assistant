/// AI 服务 Provider — 从用户偏好读取配置并创建 AIService 实例。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/ai_service.dart';
import '../../core/ai/openai_service.dart';

/// AI 配置状态（内存中保持，可扩展为持久化）
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

/// AI 配置 Provider（可读写）
final aiConfigProvider = StateNotifierProvider<AIConfigNotifier, AIConfig>((ref) {
  return AIConfigNotifier();
});

class AIConfigNotifier extends StateNotifier<AIConfig> {
  AIConfigNotifier() : super(const AIConfig());

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
