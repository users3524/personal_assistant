/// User preferences table.
library;

import 'package:drift/drift.dart';

class UserPreferences extends Table {
  @override
  String get tableName => 'user_preferences';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  TextColumn get language => text().withDefault(const Constant('zh'))();
  BoolColumn get notificationEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get aiProvider => text().withDefault(const Constant('openai'))();
  TextColumn get aiApiKey => text().nullable()();
  TextColumn get aiBaseUrl => text().nullable()();
  TextColumn get aiModel => text().nullable()();
  TextColumn get dailyReviewTime => text().withDefault(const Constant('21:00'))();
  TextColumn get weeklyReportDay => text().withDefault(const Constant('sunday'))();
  IntColumn get resumeTemplateId => integer().withDefault(const Constant(0))();
  TextColumn get todoCategories => text().withDefault(const Constant('[]'))(); // JSON list
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
