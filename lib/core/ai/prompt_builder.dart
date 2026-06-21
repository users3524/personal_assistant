/// Prompt assembly, budget estimation, clipping and online/offline gating.
library;

import 'ai_prompts.dart';
import 'llm_strategy_config.dart';

enum PromptDeliveryMode { online, offlineNote }

class PromptDeliveryDecision {
  final PromptDeliveryMode mode;
  final String reason;

  const PromptDeliveryDecision.online()
    : mode = PromptDeliveryMode.online,
      reason = '';

  const PromptDeliveryDecision.offlineNote(this.reason)
    : mode = PromptDeliveryMode.offlineNote;

  bool get shouldCallCloud => mode == PromptDeliveryMode.online;
}

class PromptBuildResult {
  final String prompt;
  final int estimatedChars;
  final int estimatedTokens;
  final int maxOutputTokens;
  final bool wasClipped;

  const PromptBuildResult({
    required this.prompt,
    required this.estimatedChars,
    required this.estimatedTokens,
    required this.maxOutputTokens,
    required this.wasClipped,
  });
}

class PromptBuilder {
  static const dailyOnlineTurnLimit = 15;

  final LLMStrategyConfig strategy;

  const PromptBuilder({this.strategy = const LLMStrategyConfig()});

  PromptDeliveryDecision decideDelivery({
    required int onlineTurnsUsedToday,
    required bool apiConfigured,
    bool forceOffline = false,
  }) {
    if (forceOffline ||
        strategy.provider == LLMStrategyConfig.offlineProvider) {
      return const PromptDeliveryDecision.offlineNote('当前处于离线模式');
    }
    if (!apiConfigured) {
      return const PromptDeliveryDecision.offlineNote('在线 AI 未配置');
    }
    if (onlineTurnsUsedToday >= dailyOnlineTurnLimit) {
      return const PromptDeliveryDecision.offlineNote('今日在线请求已达 15 轮上限');
    }
    return const PromptDeliveryDecision.online();
  }

  PromptBuildResult buildDailyReviewPrompt({
    required String summary,
    String? highlights,
    String? improvements,
    required int energyLevel,
    required int moodLevel,
    required List<String> completedTitles,
    required int pattingMinutes,
  }) {
    final prompt = AIPrompts.dailyReviewSystemPrompt(
      summary: summary,
      highlights: highlights,
      improvements: improvements,
      energyLevel: energyLevel,
      moodLevel: moodLevel,
      completedTitles: completedTitles,
      pattingMinutes: pattingMinutes,
    );
    return _fit(
      prompt,
      maxInputChars: strategy.promptBudgetChars,
      maxOutputTokens: strategy.dailyReviewMaxTokens,
    );
  }

  PromptBuildResult buildWeeklyReportPrompt({required String weekReviewsText}) {
    final prompt = AIPrompts.weeklyReportSystemPrompt(
      weekReviewsText: weekReviewsText,
    );
    return _fit(
      prompt,
      maxInputChars: strategy.promptBudgetChars,
      maxOutputTokens: strategy.weeklyReportMaxTokens,
    );
  }

  PromptBuildResult buildChatPrompt(String message) => _fit(
    message,
    maxInputChars: strategy.promptBudgetChars,
    maxOutputTokens: strategy.chatMaxTokens,
  );

  int estimateChars(String text) => text.runes.length;

  int estimateTokens(String text) {
    var tokens = 0;
    var asciiRunLength = 0;

    void flushAsciiRun() {
      if (asciiRunLength == 0) return;
      tokens += (asciiRunLength / 4).ceil();
      asciiRunLength = 0;
    }

    for (final codePoint in text.runes) {
      if (codePoint <= 0x7f) {
        if (_isAsciiWhitespace(codePoint)) {
          flushAsciiRun();
        } else {
          asciiRunLength++;
        }
      } else {
        flushAsciiRun();
        tokens++;
      }
    }
    flushAsciiRun();
    return tokens;
  }

  PromptBuildResult _fit(
    String prompt, {
    required int maxInputChars,
    required int maxOutputTokens,
  }) {
    final clipped = _clipToChars(prompt, maxInputChars);
    return PromptBuildResult(
      prompt: clipped,
      estimatedChars: estimateChars(clipped),
      estimatedTokens: estimateTokens(clipped),
      maxOutputTokens: maxOutputTokens,
      wasClipped: clipped != prompt,
    );
  }

  String _clipToChars(String text, int maxChars) {
    if (maxChars <= 0) return '';
    final runes = text.runes.toList();
    if (runes.length <= maxChars) return text;
    const suffix = '\n[已按预算截断]';
    final suffixLength = suffix.runes.length;
    if (maxChars <= suffixLength) {
      return String.fromCharCodes(runes.take(maxChars));
    }
    return String.fromCharCodes(runes.take(maxChars - suffixLength)) + suffix;
  }

  bool _isAsciiWhitespace(int codePoint) =>
      codePoint == 0x20 ||
      codePoint == 0x09 ||
      codePoint == 0x0a ||
      codePoint == 0x0d;
}
