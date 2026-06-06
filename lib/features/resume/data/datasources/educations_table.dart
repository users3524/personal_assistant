/// 教育经历表定义。
library;

import 'package:drift/drift.dart';

class Educations extends Table {
  @override
  String get tableName => 'educations';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get school => text()();
  TextColumn get major => text()();
  TextColumn get degree => text()();                       // 博士 / 硕士 / 本科 / 大专
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
