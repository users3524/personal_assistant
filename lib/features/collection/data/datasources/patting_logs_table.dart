/// 盘玩日志表定义。
///
/// 与 AntiqueItems 建立外键关联，级联删除。
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';
import 'antique_items_table.dart';

class PattingLogs extends Table {
  @override
  String get tableName => 'patting_logs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(AntiqueItems, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  IntColumn get durationMinutes => integer()();               // 盘玩时长（分钟）
  TextColumn get method => text()();                          // bare_hand | glove
  TextColumn get note => text().nullable()();
  TextColumn get photoPaths => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
}
