/// 技能表定义。
library;

import 'package:drift/drift.dart';

class SkillItems extends Table {
  @override
  String get tableName => 'skill_items';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();                     // language | framework | tool | soft
  IntColumn get proficiency => integer()();                // 1-5
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
