/// Todo items table definition.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';
import 'todo_lists_table.dart';

class Todos extends Table {
  @override
  String get tableName => 'todos';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  // 清单关联
  IntColumn get listId => integer()
      .references(TodoLists, #id, onDelete: KeyAction.setNull)
      .nullable()();

  // 自关联父任务
  IntColumn get parentId => integer()
      .nullable()
      .references(Todos, #id, onDelete: KeyAction.cascade)();

  // 重复策略: null = 不重复, 'daily' / 'weekly' / 'monthly'
  TextColumn get recurrenceRule => text().nullable()();

  TextColumn get description => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('life'))();
  IntColumn get priority => integer().withDefault(const Constant(3))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();

  // Lifecycle
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get actualMinutes => integer().nullable()();
  IntColumn get delayCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
