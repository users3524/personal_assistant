/// 日报表定义。
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class DailyReviews extends Table {
  @override
  String get tableName => 'daily_reviews';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();       // 每天一条，按日期唯一

  Set<Column> get uniqueKey => {date};
  TextColumn get summary => text()();
  TextColumn get highlights => text().nullable()();
  TextColumn get improvements => text().nullable()();
  IntColumn get energyLevel => integer()();                  // 1-5
  IntColumn get moodLevel => integer()();                    // 1-5
  TextColumn get completedTodoIds => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  IntColumn get pattingMinutes => integer()
      .withDefault(const Constant(0))();
  TextColumn get aiComment => text().nullable()();
  TextColumn get aiSuggestion => text().nullable()();
  BoolColumn get isAiGenerated => boolean().withDefault(const Constant(false))();
  BoolColumn get isManuallyEdited => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime());
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime());
}
