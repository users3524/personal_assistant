import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/core/database/backup_service.dart';

void main() {
  group('BackupService', () {
    late Directory tempDir;
    late AppDatabase sourceDb;
    var sourceClosed = false;
    AppDatabase? targetDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pa_backup_test_');
      sourceDb = AppDatabase.createInMemory();
      sourceClosed = false;
    });

    tearDown(() async {
      if (!sourceClosed) {
        await sourceDb.close();
      }
      await targetDb?.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('exports and restores schema v6 fields without data loss', () async {
      final now = DateTime(2026, 6, 20, 10, 30);
      final deletedAt = DateTime(2026, 6, 21, 9);

      await _seedSourceDatabase(sourceDb, now, deletedAt);

      final backupPath = await BackupService(
        sourceDb,
      ).exportBackupTo(tempDir.path);
      final backupJson =
          jsonDecode(await File(backupPath).readAsString())
              as Map<String, dynamic>;
      expect(backupJson['todo_lists'], isA<List<dynamic>>());
      expect(backupJson['todo_lists'], hasLength(1));

      await sourceDb.close();
      sourceClosed = true;
      targetDb = AppDatabase.createInMemory();
      final restoredDb = targetDb!;
      await BackupService(restoredDb).importBackup(backupPath);

      final prefs = await restoredDb
          .select(restoredDb.userPreferences)
          .getSingle();
      expect(prefs.todoCategories, '["life","work","ai"]');

      final lists = await restoredDb.select(restoredDb.todoLists).get();
      expect(lists, hasLength(1));
      expect(lists.single.name, 'Weekly focus');

      final todos = await (restoredDb.select(
        restoredDb.todos,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
      expect(todos, hasLength(3));
      expect(todos[0].listId, lists.single.id);
      expect(todos[0].parentId, null);
      expect(todos[0].recurrenceRule, 'weekly');
      expect(todos[1].parentId, todos[0].id);
      expect(todos[2].deletedAt, deletedAt);

      final work = await restoredDb
          .select(restoredDb.workExperiences)
          .getSingle();
      expect(work.responsibilities, ['Add mirror test', 'Fix restore columns']);
      expect(work.techStack, ['Flutter', 'Drift']);

      final project = await restoredDb
          .select(restoredDb.projectExperiences)
          .getSingle();
      expect(project.techStack, ['Riverpod', 'SQLite']);
      expect(project.keyDeliverables, [
        'Cover schema v6 fields',
        'Restore task tree',
      ]);
      expect(project.badges, ['data-safety', 'local-first']);

      final daily = await restoredDb
          .select(restoredDb.dailyReviews)
          .getSingle();
      expect(daily.date, DateTime(2026, 6, 20));
      expect(daily.completedTodoIds, ['1', '2']);
      expect(daily.pattingMinutes, 45);

      final weekly = await restoredDb
          .select(restoredDb.weeklyReports)
          .getSingle();
      expect(weekly.overview, 'Weekly overview');
      expect(weekly.highlights, 'Key progress');
      expect(weekly.improvements, 'Improvements');
      expect(weekly.nextWeekPlan, 'Next plan');
      expect(weekly.createdAt, now);
    });
  });
}

Future<void> _seedSourceDatabase(
  AppDatabase db,
  DateTime now,
  DateTime deletedAt,
) async {
  await db
      .into(db.userPreferences)
      .insert(
        UserPreferencesCompanion.insert(
          id: const Value(1),
          todoCategories: const Value('["life","work","ai"]'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  final listId = await db
      .into(db.todoLists)
      .insert(
        TodoListsCompanion.insert(
          name: 'Weekly focus',
          category: 'work',
          createdAt: Value(now),
        ),
      );

  final parentId = await db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          title: 'Finish backup restore loop',
          listId: Value(listId),
          recurrenceRule: const Value('weekly'),
          description: const Value('Cover schema v6 fields'),
          category: const Value('work'),
          priority: const Value(1),
          dueDate: Value(DateTime(2026, 6, 22)),
          status: const Value('in_progress'),
          tags: const Value(['backup', 'schema']),
          isStarred: const Value(true),
          startedAt: Value(now),
          actualMinutes: const Value(90),
          delayCount: const Value(2),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          title: 'Add tests',
          listId: Value(listId),
          parentId: Value(parentId),
          description: const Value('Subtask restore order'),
          category: const Value('work'),
          priority: const Value(2),
          status: const Value('pending'),
          tags: const Value(['test']),
          startedAt: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db
      .into(db.todos)
      .insert(
        TodosCompanion.insert(
          title: 'Legacy soft-deleted task',
          category: const Value('life'),
          priority: const Value(3),
          status: const Value('cancelled'),
          tags: const Value(['trash']),
          cancelledAt: Value(deletedAt),
          deletedAt: Value(deletedAt),
          createdAt: Value(now),
          updatedAt: Value(deletedAt),
        ),
      );

  await db
      .into(db.workExperiences)
      .insert(
        WorkExperiencesCompanion.insert(
          company: 'Personal project',
          position: 'Developer',
          startDate: DateTime(2026, 1, 1),
          description: const Value('Local-first app'),
          responsibilities: const Value([
            'Add mirror test',
            'Fix restore columns',
          ]),
          techStack: const Value(['Flutter', 'Drift']),
          sortOrder: const Value(1),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db
      .into(db.projectExperiences)
      .insert(
        ProjectExperiencesCompanion.insert(
          name: 'Personal AI Assistant',
          role: const Value('Architecture and development'),
          description: const Value('Unify backup restore flow'),
          techStack: const Value(['Riverpod', 'SQLite']),
          keyDeliverables: const Value([
            'Cover schema v6 fields',
            'Restore task tree',
          ]),
          badges: const Value(['data-safety', 'local-first']),
          startDate: DateTime(2026, 1, 1),
          sortOrder: const Value(1),
        ),
      );

  await db
      .into(db.dailyReviews)
      .insert(
        DailyReviewsCompanion.insert(
          date: DateTime(2026, 6, 20),
          summary: 'Backup fix done',
          highlights: const Value('Fields restored completely'),
          improvements: const Value('Add migration tests next'),
          energyLevel: 4,
          moodLevel: 5,
          completedTodoIds: const Value(['1', '2']),
          pattingMinutes: const Value(45),
          aiComment: const Value('Keep pace'),
          aiSuggestion: const Value('Add secure storage next'),
          isAiGenerated: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  await db
      .into(db.weeklyReports)
      .insert(
        WeeklyReportsCompanion.insert(
          weekNumber: 25,
          year: 2026,
          overview: 'Weekly overview',
          highlights: 'Key progress',
          improvements: 'Improvements',
          nextWeekPlan: 'Next plan',
          isAiGenerated: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
