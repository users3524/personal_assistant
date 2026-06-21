/// Non-sensitive LLM strategy configuration.
library;

import 'dart:convert';

import 'vector_memory_strategy.dart';

class LLMStrategyConfig {
  static const offlineProvider = '离线模式';
  static const defaultOpenAIBaseUrl = 'https://api.openai.com/v1';
  static const defaultOpenAIModel = 'gpt-4o-mini';

  final String provider;
  final String baseUrl;
  final String model;
  final int dailyReviewMaxTokens;
  final int weeklyReportMaxTokens;
  final int chatMaxTokens;
  final int promptBudgetChars;
  final VectorMemoryStrategy vectorMemory;

  const LLMStrategyConfig({
    this.provider = offlineProvider,
    this.baseUrl = '',
    this.model = '',
    this.dailyReviewMaxTokens = 500,
    this.weeklyReportMaxTokens = 1000,
    this.chatMaxTokens = 1000,
    this.promptBudgetChars = 12000,
    this.vectorMemory = const VectorMemoryStrategy(),
  });

  factory LLMStrategyConfig.fromLegacy({
    required String provider,
    String? baseUrl,
    String? model,
  }) {
    final normalizedProvider = provider.trim().isEmpty
        ? offlineProvider
        : provider.trim();
    if (normalizedProvider == offlineProvider) {
      return const LLMStrategyConfig();
    }
    return LLMStrategyConfig(
      provider: normalizedProvider,
      baseUrl: (baseUrl?.trim().isNotEmpty ?? false)
          ? baseUrl!.trim()
          : defaultOpenAIBaseUrl,
      model: (model?.trim().isNotEmpty ?? false)
          ? model!.trim()
          : defaultOpenAIModel,
    );
  }

  factory LLMStrategyConfig.fromJson(Map<String, dynamic> json) {
    final provider = json['provider']?.toString().trim();
    final baseUrl = json['baseUrl']?.toString().trim();
    final model = json['model']?.toString().trim();
    return LLMStrategyConfig(
      provider: provider == null || provider.isEmpty
          ? offlineProvider
          : provider,
      baseUrl: baseUrl ?? '',
      model: model ?? '',
      dailyReviewMaxTokens: _readPositiveInt(
        json['dailyReviewMaxTokens'],
        fallback: 500,
      ),
      weeklyReportMaxTokens: _readPositiveInt(
        json['weeklyReportMaxTokens'],
        fallback: 1000,
      ),
      chatMaxTokens: _readPositiveInt(json['chatMaxTokens'], fallback: 1000),
      promptBudgetChars: _readPositiveInt(
        json['promptBudgetChars'],
        fallback: 12000,
      ),
      vectorMemory: VectorMemoryStrategy.fromJson(
        json['vectorMemory'] is Map<String, dynamic>
            ? json['vectorMemory'] as Map<String, dynamic>
            : null,
      ),
    );
  }

  factory LLMStrategyConfig.fromJsonString(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) {
      return const LLMStrategyConfig();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('LLM strategy config must be a JSON object');
    }
    return LLMStrategyConfig.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'baseUrl': baseUrl,
    'model': model,
    'dailyReviewMaxTokens': dailyReviewMaxTokens,
    'weeklyReportMaxTokens': weeklyReportMaxTokens,
    'chatMaxTokens': chatMaxTokens,
    'promptBudgetChars': promptBudgetChars,
    'vectorMemory': vectorMemory.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());

  static int _readPositiveInt(dynamic value, {required int fallback}) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed <= 0) return fallback;
    return parsed;
  }
}
