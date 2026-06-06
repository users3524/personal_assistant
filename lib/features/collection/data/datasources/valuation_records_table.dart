/// Valuation records table.
/// Foreign key to AntiqueItems, cascade delete.

import 'package:drift/drift.dart';

import 'antique_items_table.dart';

class ValuationRecords extends Table {
  @override
  String get tableName => 'valuation_records';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(AntiqueItems, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get remark => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
