import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/ai_output_parser.dart';

void main() {
  group('AIOutputParser', () {
    test('parses normal daily output', () {
      final output = AIOutputParser.parseDaily('''
1. 评语：今天执行很稳，节奏也不错。
2. 改进建议：明天先做最重要的一件事。
3. 情绪标签：高效
''');

      expect(output.comment, '今天执行很稳，节奏也不错。');
      expect(output.suggestion, '明天先做最重要的一件事。');
      expect(output.sentimentTag, '高效');
    });

    test('preserves malformed daily output visibly', () {
      final output = AIOutputParser.parseDaily('这是一段没有任何标签的模型原文。');

      expect(output.comment, contains('AI 返回格式未完全符合预期'));
      expect(output.comment, contains('这是一段没有任何标签的模型原文'));
      expect(output.suggestion, contains('手动调整'));
      expect(output.sentimentTag, '平稳');
    });

    test('parses strict daily JSON output', () {
      final output = AIOutputParser.tryParseDailyJson('''
{
  "comment": "今天节奏稳定，关键任务推进得很踏实。",
  "suggestion": "明天先处理最重要的一件事，再安排零散事项。",
  "sentiment_tag": "高效"
}
''');

      expect(output?.comment, '今天节奏稳定，关键任务推进得很踏实。');
      expect(output?.suggestion, '明天先处理最重要的一件事，再安排零散事项。');
      expect(output?.sentimentTag, '高效');
    });

    test('rejects malformed daily JSON output', () {
      final output = AIOutputParser.tryParseDailyJson('{"comment":"缺字段"}');

      expect(output, null);
    });

    test('fills missing weekly sections with visible placeholders', () {
      final output = AIOutputParser.parseWeekly('''
【本周概览】
整体节奏稳定。

【本周亮点】
• 完成了关键任务。
''');

      expect(output.overview, '整体节奏稳定。');
      expect(output.highlights, '• 完成了关键任务。');
      expect(output.improvements, contains('缺少「待改进」'));
      expect(output.nextWeekPlan, contains('缺少「下周计划」'));
    });

    test('preserves malformed weekly output visibly', () {
      final output = AIOutputParser.parseWeekly('模型没有分段，只输出了一整段建议。');

      expect(output.overview, contains('AI 返回格式未完全符合预期'));
      expect(output.highlights, contains('模型没有分段'));
      expect(output.improvements, contains('手动校准'));
      expect(output.nextWeekPlan, contains('手动校准'));
    });
  });
}
