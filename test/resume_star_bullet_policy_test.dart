import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/resume/domain/entities/resume_entity.dart';
import 'package:personal_assistant/features/resume/domain/services/resume_star_bullet_policy.dart';

void main() {
  group('ResumeStarBulletPolicy', () {
    const policy = ResumeStarBulletPolicy(maxBulletChars: 80);

    test('builds prompts that explicitly bind STAR output to local facts', () {
      final prompt = policy.buildFactBoundPrompt(_facts());

      expect(prompt, contains('只能使用事实区出现的信息'));
      expect(prompt, contains('最多输出 3 条 bullet'));
      expect(prompt, contains('只输出纯文本'));
      expect(prompt, contains('寸积个人助手'));
      expect(prompt, contains('Flutter'));
      expect(prompt, contains('备份恢复镜像测试'));
    });

    test('keeps at most three fact-supported bullets', () {
      final result = policy.sanitizeBullets(
        facts: _facts(),
        rawBullets: const [
          '负责寸积个人助手的备份恢复镜像测试，覆盖任务树和周报字段',
          '基于 Flutter 和 Drift 实现本地优先的数据管理体验',
          '推动项目经历关键交付字段落地，支持模板展示',
          '负责寸积个人助手设置页重构',
        ],
      );

      expect(result.bullets, [
        '负责寸积个人助手的备份恢复镜像测试，覆盖任务树和周报字段',
        '基于 Flutter 和 Drift 实现本地优先的数据管理体验',
        '推动项目经历关键交付字段落地，支持模板展示',
      ]);
      expect(result.droppedOverflowCount, 1);
      expect(result.wasLimited, true);
    });

    test('rejects unsupported quantitative claims', () {
      final result = policy.sanitizeBullets(
        facts: _facts(),
        rawBullets: const ['将备份恢复成功率提升 99%', '备份恢复镜像测试覆盖 12 张表'],
      );

      expect(result.bullets, ['备份恢复镜像测试覆盖 12 张表']);
      expect(result.droppedUnsupportedFactCount, 1);
    });

    test('rejects unsupported toolchain claims', () {
      final result = policy.sanitizeBullets(
        facts: _facts(),
        rawBullets: const ['使用 React 重构简历项目展示', '使用 Flutter 优化简历项目展示'],
      );

      expect(result.bullets, ['使用 Flutter 优化简历项目展示']);
      expect(result.droppedUnsupportedFactCount, 1);
    });

    test('removes bullet markers, markdown and html before persisting', () {
      final result = policy.sanitizeTextOutput(
        facts: _facts(),
        output: '''
• **备份恢复镜像测试** 覆盖任务树和周报字段
2. <b>Flutter</b> 项目经历关键交付字段支持模板展示
''',
      );

      expect(result.bullets, [
        '备份恢复镜像测试 覆盖任务树和周报字段',
        'Flutter 项目经历关键交付字段支持模板展示',
      ]);
    });

    test('deduplicates equivalent bullets and drops empty lines', () {
      final result = policy.sanitizeTextOutput(
        facts: _facts(),
        output: '''

- 备份恢复镜像测试覆盖任务树
• 备份恢复镜像测试覆盖任务树
''',
      );

      expect(result.bullets, ['备份恢复镜像测试覆盖任务树']);
      expect(result.droppedEmptyCount, 0);
      expect(result.droppedDuplicateCount, 1);
    });

    test('truncates long bullets in code before persistence', () {
      const shortPolicy = ResumeStarBulletPolicy(maxBulletChars: 18);
      final result = shortPolicy.sanitizeBullets(
        facts: _facts(),
        rawBullets: const ['备份恢复镜像测试覆盖任务树和周报字段并支持模板展示'],
      );

      expect(result.bullets.single.runes.length, 18);
      expect(result.bullets.single, endsWith('…'));
      expect(result.truncatedCount, 1);
    });

    test('builds fact pack from project experience and external evidence', () {
      final facts = ResumeStarFactPack.fromProject(
        ProjectExperienceEntity(
          id: 1,
          name: '寸积个人助手',
          role: 'Flutter 开发',
          description: '本地优先个人管理工具',
          techStack: const ['Flutter', 'Drift'],
          keyDeliverables: const ['备份恢复镜像测试覆盖 12 张表'],
          badges: const ['local-first'],
          startDate: DateTime(2026, 6, 1),
        ),
        milestoneSummaries: const ['项目经历关键交付字段落地'],
        todoDescriptions: const ['补齐周报字段恢复测试'],
      );

      expect(facts.allFacts, contains('寸积个人助手'));
      expect(facts.allFacts, contains('备份恢复镜像测试覆盖 12 张表'));
      expect(facts.allFacts, contains('项目经历关键交付字段落地'));
      expect(facts.allFacts, contains('补齐周报字段恢复测试'));
    });

    test('rejects invalid max bullet length', () {
      expect(
        () => const ResumeStarBulletPolicy(
          maxBulletChars: 0,
        ).sanitizeBullets(facts: _facts(), rawBullets: const []),
        throwsArgumentError,
      );
    });
  });
}

ResumeStarFactPack _facts() {
  return const ResumeStarFactPack(
    projectName: '寸积个人助手',
    role: 'Flutter 开发',
    description: '本地优先个人管理工具',
    techStack: ['Flutter', 'Drift', 'Riverpod'],
    keyDeliverables: ['备份恢复镜像测试覆盖 12 张表', '项目经历关键交付字段支持模板展示'],
    badges: ['local-first'],
    milestoneSummaries: ['高光表和项目经历多对多关联落地'],
    todoDescriptions: ['补齐任务树和周报字段恢复测试'],
  );
}
