import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/core/database/app_database_provider.dart';
import 'package:personal_assistant/features/resume/data/datasources/resume_dao.dart';
import 'package:personal_assistant/features/resume/presentation/pages/resume_home_page.dart';

void main() {
  group('resume edit page', () {
    late AppDatabase db;
    late ResumeDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = ResumeDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('saves project key deliverables from multiline input', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
          child: const MaterialApp(home: ResumeHomePage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('添加项目经历'));
      await tester.tap(find.text('添加项目经历'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '项目名称'),
        '个人助手',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '关键交付'),
        '  本地安全存储  \n\n备份镜像恢复  ',
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final projects = await dao.getProjects();

      expect(projects, hasLength(1));
      expect(projects.single.name, '个人助手');
      expect(projects.single.keyDeliverables, ['本地安全存储', '备份镜像恢复']);
    });

    testWidgets('saves project badges from delimited input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
          child: const MaterialApp(home: ResumeHomePage()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('添加项目经历'));
      await tester.tap(find.text('添加项目经历'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, '项目名称'),
        '简历引擎',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '项目标签'),
        ' Flutter, 本地优先\n数据安全；离线可用 ',
      );

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final projects = await dao.getProjects();

      expect(projects, hasLength(1));
      expect(projects.single.name, '简历引擎');
      expect(projects.single.badges, ['Flutter', '本地优先', '数据安全', '离线可用']);
    });
  });
}
