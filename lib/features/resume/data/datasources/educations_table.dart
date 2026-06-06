/// Education experiences table.

import 'package:drift/drift.dart';

class Educations extends Table {
  @override String get tableName => 'educations';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get school => text()();
  TextColumn get major => text()();
  TextColumn get degree => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
