/// 应用数据库定义。
///
/// 使用 drift 框架生成类型安全的 SQLite 数据库访问层。
/// 通过 `drift_dev` 的 build_runner 自动生成 `app_database.g.dart`。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/todo/data/datasources/todos_table.dart';
import '../../features/ai_assistant/data/datasources/daily_reviews_table.dart';
import '../../features/ai_assistant/data/datasources/weekly_reports_table.dart';
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

part 'app_database.g.dart';

/// 所有数据库表的集合
@DriftDatabase(
  tables: [
    // Core
    UserPreferences,

    // Feature: Todo
    Todos,

    // Feature: Collection
    AntiqueItems,
    ValuationRecords,
    PattingLogs,

    // Feature: AI Assistant
    DailyReviews,
    WeeklyReports,

    // Feature: Resume
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
  int get schemaVersion => 1;

  /// 创建数据库实例（使用默认文件路径）
  static Future<AppDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'personal_assistant.db'));
    return AppDatabase(NativeDatabase(file));
  }

  /// 创建内存数据库（用于测试）
  static AppDatabase createInMemory() {
    return AppDatabase(NativeDatabase.memory());
  }
}
