import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/llm_strategy_config.dart';
import 'package:personal_assistant/core/ai/prompt_builder.dart';

void main() {
  group('PromptBuilder', () {
    test('builds daily review prompt with configured output budget', () {
      const builder = PromptBuilder(
        strategy: LLMStrategyConfig(
          provider: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
          dailyReviewMaxTokens: 640,
        ),
      );

      final result = builder.buildDailyReviewPrompt(
        summary: '完成了本地备份恢复',
        highlights: '修复图片路径',
        improvements: '补测试',
        energyLevel: 4,
        moodLevel: 4,
        completedTitles: const ['整理 TODO', '补迁移测试'],
        pattingMinutes: 30,
      );

      expect(result.prompt, contains('完成了本地备份恢复'));
      expect(result.prompt, contains('整理 TODO、补迁移测试'));
      expect(result.prompt, contains('盘玩放松：30分钟'));
      expect(result.maxOutputTokens, 640);
      expect(result.wasClipped, false);
    });

    test('clips prompts by character budget', () {
      const builder = PromptBuilder(
        strategy: LLMStrategyConfig(promptBudgetChars: 24),
      );

      final result = builder.buildChatPrompt('一二三四五六七八九十abcdefg一二三四五六七八九十');

      expect(result.wasClipped, true);
      expect(result.estimatedChars, lessThanOrEqualTo(24));
      expect(result.prompt, contains('已按预算截断'));
    });

    test('estimates ascii and CJK token costs differently', () {
      const builder = PromptBuilder();

      expect(builder.estimateTokens('abcdefgh'), 2);
      expect(builder.estimateTokens('复盘完成'), 4);
    });

    test('routes to offline note when turn limit or config blocks cloud', () {
      const builder = PromptBuilder(
        strategy: LLMStrategyConfig(
          provider: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
        ),
      );

      expect(
        builder
            .decideDelivery(onlineTurnsUsedToday: 14, apiConfigured: true)
            .shouldCallCloud,
        true,
      );
      expect(
        builder
            .decideDelivery(onlineTurnsUsedToday: 15, apiConfigured: true)
            .mode,
        PromptDeliveryMode.offlineNote,
      );
      expect(
        builder
            .decideDelivery(onlineTurnsUsedToday: 0, apiConfigured: false)
            .mode,
        PromptDeliveryMode.offlineNote,
      );
    });
  });
}
