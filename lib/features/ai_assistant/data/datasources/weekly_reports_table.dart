/// 周报表定义。
library;

import 'package:drift/drift.dart';

class WeeklyReports extends Table {
  @override
  String get tableName => 'weekly_reports';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get weekNumber => integer()();                   // 年内第几周 (1-53)
  IntColumn get year => integer()();
  TextColumn get overview => text()();
  TextColumn get highlights => text()();
  TextColumn get improvements => text()();
  TextColumn get nextWeekPlan => text()();
  BoolColumn get isAiGenerated => boolean().withDefault(const Constant(false))();
  BoolColumn get isManuallyEdited => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();

  @override
  Set<Column> get uniqueKey => {weekNumber, year};
}
