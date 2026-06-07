/// Collection categories table — stores 文玩 categories, subtypes, and metadata fields.
library;

import 'package:drift/drift.dart';

class CollectionCategories extends Table {
  @override
  String get tableName => 'collection_categories';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get subtypes => text().withDefault(const Constant('[]'))();      // JSON list
  TextColumn get metadataFields => text().withDefault(const Constant('[]'))(); // JSON list
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
