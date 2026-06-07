/// Work experiences table.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class WorkExperiences extends Table {
  @override
  String get tableName => 'work_experiences';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get company => text()();
  TextColumn get position => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();    // null = present
  TextColumn get description => text().nullable()();
  TextColumn get techStack => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
