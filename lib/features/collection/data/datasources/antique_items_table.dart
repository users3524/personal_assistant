/// 藏品主表定义。
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class AntiqueItems extends Table {
  @override
  String get tableName => 'antique_items';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();  // 松石 | 南红 | 菩提 | 翡翠 | 和田玉 | 紫砂 | 书画 | 杂项 | 自定义
  TextColumn get subtype => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get acquiredDate => dateTime()();
  RealColumn get acquiredPrice => real().nullable()();
  TextColumn get sourceSeller => text().nullable()();
  TextColumn get condition => text().withDefault(const Constant('good'))();  // perfect | good | fair | poor
  RealColumn get currentValuation => real().nullable()();
  TextColumn get imagePaths => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get fingerprints => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime());
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime());
}
