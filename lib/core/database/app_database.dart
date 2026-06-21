/// App database definition.
///
/// Uses drift framework for type-safe SQLite database access.
library app_database;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/todo/data/datasources/todos_table.dart';
import '../../features/todo/data/datasources/todo_lists_table.dart';
import '../../features/ai_assistant/data/datasources/daily_reviews_table.dart';
import '../../features/ai_assistant/data/datasources/weekly_reports_table.dart';
import '../../features/ai_assistant/data/datasources/chat_turns_table.dart';
import '../../features/collection/data/datasources/antique_items_table.dart';
import '../../features/collection/data/datasources/valuation_records_table.dart';
import '../../features/collection/data/datasources/patting_logs_table.dart';
import '../../features/resume/data/datasources/resume_profile_table.dart';
import '../../features/resume/data/datasources/work_experiences_table.dart';
import '../../features/resume/data/datasources/educations_table.dart';
import '../../features/resume/data/datasources/skill_items_table.dart';
import '../../features/resume/data/datasources/project_experiences_table.dart';
import 'converters/string_list_converter.dart';
import 'tables/user_preferences_table.dart';
import 'tables/collection_categories_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UserPreferences,
    CollectionCategories,
    TodoLists,
    Todos,
    AntiqueItems,
    ValuationRecords,
    PattingLogs,
    DailyReviews,
    WeeklyReports,
    ChatTurns,
    ResumeProfile,
    WorkExperiences,
    Educations,
    SkillItems,
    ProjectExperiences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(antiqueItems, antiqueItems.categoryMetadata);
      }
      if (from < 3) {
        await m.createTable(collectionCategories);
      }
      if (from < 4) {
        await m.addColumn(userPreferences, userPreferences.todoCategories);
      }
      if (from < 5) {
        await m.addColumn(todos, todos.deletedAt);
      }
      if (from < 6) {
        await m.createTable(todoLists);
        await m.addColumn(todos, todos.listId);
        await m.addColumn(todos, todos.parentId);
        await m.addColumn(todos, todos.recurrenceRule);
      }
      if (from < 7) {
        await _createTodoIndexes();
      }
      if (from < 8) {
        await _createPattingLogIndexes();
      }
      if (from < 9) {
        await m.addColumn(userPreferences, userPreferences.aiConfig);
      }
      if (from < 10) {
        await m.createTable(chatTurns);
        await _createChatTurnIndexes();
      }
    },
  );

  Future<void> _createTodoIndexes() async {
    for (final statement in todoIndexStatements) {
      await customStatement(statement);
    }
  }

  Future<void> _createPattingLogIndexes() async {
    for (final statement in pattingLogIndexStatements) {
      await customStatement(statement);
    }
  }

  Future<void> _createChatTurnIndexes() async {
    for (final statement in chatTurnIndexStatements) {
      await customStatement(statement);
    }
  }

  static Future<AppDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'personal_assistant.db'));
    return AppDatabase(NativeDatabase(file));
  }

  static AppDatabase createInMemory() {
    return AppDatabase(NativeDatabase.memory());
  }
}
