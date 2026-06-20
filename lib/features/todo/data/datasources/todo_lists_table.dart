/// TodoLists table — 清单实体。
library;

import 'package:drift/drift.dart';

class TodoLists extends Table {
  @override
  String get tableName => 'todo_lists';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get category => text().withLength(min: 1)(); // '生活' / '工作' 等
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
