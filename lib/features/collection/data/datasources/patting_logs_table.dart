/// Patting logs table.
/// Foreign key to AntiqueItems, cascade delete.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';
import 'antique_items_table.dart';

const String createPattingLogsItemDateIndex =
    'CREATE INDEX IF NOT EXISTS idx_patting_logs_item_date '
    'ON patting_logs(item_id, date DESC)';
const String createPattingLogsDateItemIndex =
    'CREATE INDEX IF NOT EXISTS idx_patting_logs_date_item '
    'ON patting_logs(date, item_id)';

const List<String> pattingLogIndexStatements = [
  createPattingLogsItemDateIndex,
  createPattingLogsDateItemIndex,
];

@TableIndex.sql(createPattingLogsItemDateIndex)
@TableIndex.sql(createPattingLogsDateItemIndex)
class PattingLogs extends Table {
  @override
  String get tableName => 'patting_logs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().references(AntiqueItems, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationMinutes => integer()(); // Duration in minutes
  TextColumn get method => text()(); // bare_hand | glove
  TextColumn get note => text().nullable()();
  TextColumn get photoPaths => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
