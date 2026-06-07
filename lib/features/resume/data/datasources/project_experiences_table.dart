/// Project experiences table.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class ProjectExperiences extends Table {
  @override
  String get tableName => 'project_experiences';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get role => text()();
  TextColumn get description => text().nullable()();
  TextColumn get techStack => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get link => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
