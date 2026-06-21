import 'package:drift/drift.dart';

import 'milestones_table.dart';

const String createMilestoneRelationsMilestoneIndex =
    'CREATE INDEX IF NOT EXISTS idx_milestone_relations_milestone '
    'ON milestone_relations(milestone_id, created_at)';
const String createMilestoneRelationsSourceIndex =
    'CREATE INDEX IF NOT EXISTS idx_milestone_relations_source '
    'ON milestone_relations(source_type, source_id)';

const milestoneRelationIndexStatements = [
  createMilestoneRelationsMilestoneIndex,
  createMilestoneRelationsSourceIndex,
];

@TableIndex.sql(createMilestoneRelationsMilestoneIndex)
@TableIndex.sql(createMilestoneRelationsSourceIndex)
class MilestoneRelations extends Table {
  @override
  String get tableName => 'milestone_relations';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get milestoneId =>
      integer().references(Milestones, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceType => text()();
  IntColumn get sourceId => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => const [
    "CHECK (source_type IN ('todo', 'daily_review', 'patting_log', 'manual'))",
    "CHECK ((source_type = 'manual' AND source_id IS NULL) OR "
        "(source_type <> 'manual' AND source_id IS NOT NULL))",
  ];
}
