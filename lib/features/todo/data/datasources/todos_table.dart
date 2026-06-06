/// 待办事项表定义。
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class Todos extends Table {
  @override
  String get tableName => 'todos';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('life'))();  // life | work
  IntColumn get priority => integer().withDefault(const Constant(3))();    // 1-5
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending | in_progress | done | cancelled
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();

  // 生命周期追踪
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  IntColumn get actualMinutes => integer().nullable()();
  IntColumn get delayCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();
}
