import 'package:drift/drift.dart';

import '../../../resume/data/datasources/project_experiences_table.dart';
import 'milestones_table.dart';

const String createProjectMilestoneRelationsProjectIndex =
    'CREATE INDEX IF NOT EXISTS idx_project_milestone_relations_project '
    'ON project_milestone_relations(project_id, sort_order, milestone_id)';
const String createProjectMilestoneRelationsMilestoneIndex =
    'CREATE INDEX IF NOT EXISTS idx_project_milestone_relations_milestone '
    'ON project_milestone_relations(milestone_id, project_id)';
const String createProjectMilestoneRelationsUniqueIndex =
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_project_milestone_relations_unique '
    'ON project_milestone_relations(project_id, milestone_id)';

const projectMilestoneRelationIndexStatements = [
  createProjectMilestoneRelationsProjectIndex,
  createProjectMilestoneRelationsMilestoneIndex,
  createProjectMilestoneRelationsUniqueIndex,
];

@TableIndex.sql(createProjectMilestoneRelationsProjectIndex)
@TableIndex.sql(createProjectMilestoneRelationsMilestoneIndex)
@TableIndex.sql(createProjectMilestoneRelationsUniqueIndex)
class ProjectMilestoneRelations extends Table {
  @override
  String get tableName => 'project_milestone_relations';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(
    ProjectExperiences,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get milestoneId =>
      integer().references(Milestones, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
