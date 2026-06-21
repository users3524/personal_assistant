import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/resume/domain/services/resume_ai_output_sanitizer.dart';

void main() {
  group('ResumeAiOutputSanitizer', () {
    test('accepts plain text and strips decorative markdown or html', () {
      const sanitizer = ResumeAiOutputSanitizer();

      final result = sanitizer.sanitizeText(
        '<b>本地优先个人助手</b>\n**负责备份恢复镜像测试**\n[项目链接](https://example.com)',
      );

      expect(result.text, '本地优先个人助手\n负责备份恢复镜像测试\n项目链接');
      expect(result.wasChanged, true);
    });

    test('drops style and layout instruction lines from text output', () {
      const sanitizer = ResumeAiOutputSanitizer();

      final result = sanitizer.sanitizeText('''
负责备份恢复镜像测试
请使用双栏布局，标题字号 18，颜色 #333
Use CSS grid and font-size 14px
推动项目经历关键交付字段落地
''');

      expect(result.text, '负责备份恢复镜像测试\n推动项目经历关键交付字段落地');
    });

    test('clips long text before persistence', () {
      const sanitizer = ResumeAiOutputSanitizer(maxTextChars: 12);

      final result = sanitizer.sanitizeText('备份恢复镜像测试覆盖任务树和周报字段');

      expect(result.text.runes.length, 12);
      expect(result.text, endsWith('…'));
    });

    test('accepts only string arrays for list output', () {
      const sanitizer = ResumeAiOutputSanitizer();

      final result = sanitizer.sanitizeStringList([
        '负责备份恢复镜像测试',
        '**推动项目经历字段落地**',
      ]);

      expect(result.items, ['负责备份恢复镜像测试', '推动项目经历字段落地']);
    });

    test('drops empty and layout instruction items from string arrays', () {
      const sanitizer = ResumeAiOutputSanitizer();

      final result = sanitizer.sanitizeStringList([
        '  ',
        '标题使用蓝色，整体布局改成双栏',
        'Use HTML <span style="color:red">layout</span>',
        '保留纯文本成果描述',
      ]);

      expect(result.items, ['保留纯文本成果描述']);
      expect(result.droppedEmptyCount, 1);
      expect(result.droppedInstructionCount, 2);
      expect(result.wasChanged, true);
    });

    test('clips list item length and item count', () {
      const sanitizer = ResumeAiOutputSanitizer(maxItemChars: 10, maxItems: 2);

      final result = sanitizer.sanitizeStringList([
        '备份恢复镜像测试覆盖任务树',
        '项目经历关键交付字段支持模板展示',
        '这一条超过数量上限',
      ]);

      expect(result.items, hasLength(2));
      expect(result.items.first.runes.length, 10);
      expect(result.items.first, endsWith('…'));
      expect(result.truncatedCount, 1);
    });

    test('rejects non-string text and non-string list values', () {
      const sanitizer = ResumeAiOutputSanitizer();

      expect(() => sanitizer.sanitizeText(['not text']), throwsArgumentError);
      expect(
        () => sanitizer.sanitizeStringList('not list'),
        throwsArgumentError,
      );
      expect(
        () => sanitizer.sanitizeStringList(['ok', 42]),
        throwsArgumentError,
      );
    });

    test('rejects invalid limits', () {
      expect(
        () =>
            const ResumeAiOutputSanitizer(maxTextChars: 0).sanitizeText('text'),
        throwsArgumentError,
      );
      expect(
        () => const ResumeAiOutputSanitizer(
          maxItemChars: 0,
        ).sanitizeStringList(const []),
        throwsArgumentError,
      );
      expect(
        () => const ResumeAiOutputSanitizer(
          maxItems: 0,
        ).sanitizeStringList(const []),
        throwsArgumentError,
      );
    });
  });
}
