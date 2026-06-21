import 'package:drift/drift.dart';

const String createMilestonesConfirmedOccurredIndex =
    'CREATE INDEX IF NOT EXISTS idx_milestones_confirmed_occurred '
    'ON milestones(is_confirmed_by_user, occurred_at DESC)';

const milestoneIndexStatements = [createMilestonesConfirmedOccurredIndex];

@TableIndex.sql(createMilestonesConfirmedOccurredIndex)
class Milestones extends Table {
  @override
  String get tableName => 'milestones';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get importanceScore => integer().withDefault(const Constant(0))();
  BoolColumn get isAiGenerated =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isConfirmedByUser =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
