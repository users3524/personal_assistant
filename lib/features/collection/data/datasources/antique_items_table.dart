/// Antique items table.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class AntiqueItems extends Table {
  @override String get tableName => 'antique_items';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get subtype => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get acquiredDate => dateTime()();
  RealColumn get acquiredPrice => real().nullable()();
  TextColumn get sourceSeller => text().nullable()();
  TextColumn get condition => text().withDefault(const Constant('good'))();
  RealColumn get currentValuation => real().nullable()();
  TextColumn get imagePaths => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  TextColumn get categoryMetadata => text().nullable()(); // JSON: 分类专属字段
  TextColumn get fingerprints => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
