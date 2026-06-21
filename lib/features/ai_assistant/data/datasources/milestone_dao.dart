import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/milestone_entity.dart';

class MilestoneDao {
  final AppDatabase _db;

  MilestoneDao(this._db);

  MilestoneEntity _toMilestoneEntity(Milestone row) => MilestoneEntity(
    id: row.id,
    title: row.title,
    description: row.description,
    occurredAt: row.occurredAt,
    importanceScore: row.importanceScore,
    isAiGenerated: row.isAiGenerated,
    isConfirmedByUser: row.isConfirmedByUser,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  MilestonesCompanion _toMilestoneCompanion(MilestoneEntity entity) {
    return MilestonesCompanion(
      title: Value(entity.title),
      description: Value(entity.description),
      occurredAt: Value(entity.occurredAt),
      importanceScore: Value(entity.importanceScore),
      isAiGenerated: Value(entity.isAiGenerated),
      isConfirmedByUser: Value(entity.isConfirmedByUser),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  MilestoneRelationEntity _toRelationEntity(MilestoneRelation row) {
    return MilestoneRelationEntity(
      id: row.id,
      milestoneId: row.milestoneId,
      sourceType: MilestoneSourceType.fromStorage(row.sourceType),
      sourceId: row.sourceId,
      note: row.note,
      createdAt: row.createdAt,
    );
  }

  MilestoneRelationsCompanion _toRelationCompanion(
    MilestoneRelationEntity entity,
  ) {
    return MilestoneRelationsCompanion(
      milestoneId: Value(entity.milestoneId),
      sourceType: Value(entity.sourceType.storageValue),
      sourceId: Value(entity.sourceId),
      note: Value(entity.note),
      createdAt: Value(entity.createdAt),
    );
  }

  ProjectMilestoneRelationEntity _toProjectRelationEntity(
    ProjectMilestoneRelation row,
  ) {
    return ProjectMilestoneRelationEntity(
      id: row.id,
      projectId: row.projectId,
      milestoneId: row.milestoneId,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
    );
  }

  ProjectMilestoneRelationsCompanion _toProjectRelationCompanion(
    ProjectMilestoneRelationEntity entity,
  ) {
    return ProjectMilestoneRelationsCompanion(
      projectId: Value(entity.projectId),
      milestoneId: Value(entity.milestoneId),
      sortOrder: Value(entity.sortOrder),
      createdAt: Value(entity.createdAt),
    );
  }

  Future<MilestoneEntity> insertMilestone(MilestoneEntity entity) async {
    final id = await _db
        .into(_db.milestones)
        .insert(_toMilestoneCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<MilestoneRelationEntity> insertRelation(
    MilestoneRelationEntity entity,
  ) async {
    _validateRelation(entity);
    final id = await _db
        .into(_db.milestoneRelations)
        .insert(_toRelationCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<MilestoneEntity> createMilestoneWithRelations(
    MilestoneEntity milestone,
    List<MilestoneRelationEntity> relations,
  ) async {
    return _db.transaction(() async {
      final created = await insertMilestone(milestone);
      for (final relation in relations) {
        await insertRelation(
          MilestoneRelationEntity(
            milestoneId: created.id!,
            sourceType: relation.sourceType,
            sourceId: relation.sourceId,
            note: relation.note,
            createdAt: relation.createdAt,
          ),
        );
      }
      return created;
    });
  }

  Future<MilestoneEntity?> getMilestoneById(int id) async {
    final row = await (_db.select(
      _db.milestones,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toMilestoneEntity(row);
  }

  Future<List<MilestoneEntity>> getMilestones({bool? confirmedOnly}) async {
    final query = _db.select(_db.milestones)
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    if (confirmedOnly != null) {
      query.where((t) => t.isConfirmedByUser.equals(confirmedOnly));
    }
    final rows = await query.get();
    return rows.map(_toMilestoneEntity).toList();
  }

  Future<List<MilestoneRelationEntity>> getRelationsForMilestone(
    int milestoneId,
  ) async {
    final rows =
        await (_db.select(_db.milestoneRelations)
              ..where((t) => t.milestoneId.equals(milestoneId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_toRelationEntity).toList();
  }

  Future<List<MilestoneEntity>> getMilestonesBySource({
    required MilestoneSourceType sourceType,
    int? sourceId,
  }) async {
    if (sourceType != MilestoneSourceType.manual && sourceId == null) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Non-manual milestone sources require a source id.',
      );
    }

    final rows =
        await (_db.select(_db.milestones).join([
                innerJoin(
                  _db.milestoneRelations,
                  _db.milestoneRelations.milestoneId.equalsExp(
                    _db.milestones.id,
                  ),
                ),
              ])
              ..where(
                _db.milestoneRelations.sourceType.equals(
                      sourceType.storageValue,
                    ) &
                    (sourceId == null
                        ? _db.milestoneRelations.sourceId.isNull()
                        : _db.milestoneRelations.sourceId.equals(sourceId)),
              )
              ..orderBy([OrderingTerm.desc(_db.milestones.occurredAt)]))
            .get();

    return rows
        .map((row) => row.readTable(_db.milestones))
        .map(_toMilestoneEntity)
        .toList();
  }

  Future<int> deleteRelationsBySource({
    required MilestoneSourceType sourceType,
    int? sourceId,
  }) async {
    if (sourceType != MilestoneSourceType.manual && sourceId == null) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Non-manual milestone sources require a source id.',
      );
    }
    return (_db.delete(_db.milestoneRelations)..where(
          (t) =>
              t.sourceType.equals(sourceType.storageValue) &
              (sourceId == null
                  ? t.sourceId.isNull()
                  : t.sourceId.equals(sourceId)),
        ))
        .go();
  }

  Future<ProjectMilestoneRelationEntity> bindMilestoneToProject(
    ProjectMilestoneRelationEntity entity,
  ) async {
    final id = await _db
        .into(_db.projectMilestoneRelations)
        .insert(
          _toProjectRelationCompanion(entity),
          mode: InsertMode.insertOrReplace,
        );
    return entity.copyWith(id: id);
  }

  Future<int> unbindMilestoneFromProject({
    required int projectId,
    required int milestoneId,
  }) {
    return (_db.delete(_db.projectMilestoneRelations)..where(
          (t) =>
              t.projectId.equals(projectId) & t.milestoneId.equals(milestoneId),
        ))
        .go();
  }

  Future<List<ProjectMilestoneRelationEntity>> getProjectMilestoneRelations(
    int projectId,
  ) async {
    final rows =
        await (_db.select(_db.projectMilestoneRelations)
              ..where((t) => t.projectId.equals(projectId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    return rows.map(_toProjectRelationEntity).toList();
  }

  Future<List<MilestoneEntity>> getMilestonesForProject(int projectId) async {
    final rows =
        await (_db.select(_db.milestones).join([
                innerJoin(
                  _db.projectMilestoneRelations,
                  _db.projectMilestoneRelations.milestoneId.equalsExp(
                    _db.milestones.id,
                  ),
                ),
              ])
              ..where(_db.projectMilestoneRelations.projectId.equals(projectId))
              ..orderBy([
                OrderingTerm.asc(_db.projectMilestoneRelations.sortOrder),
                OrderingTerm.desc(_db.milestones.occurredAt),
              ]))
            .get();

    return rows
        .map((row) => row.readTable(_db.milestones))
        .map(_toMilestoneEntity)
        .toList();
  }

  Future<List<int>> getProjectIdsForMilestone(int milestoneId) async {
    final rows =
        await (_db.select(_db.projectMilestoneRelations)
              ..where((t) => t.milestoneId.equals(milestoneId))
              ..orderBy([(t) => OrderingTerm.asc(t.projectId)]))
            .get();
    return rows.map((row) => row.projectId).toList();
  }

  void _validateRelation(MilestoneRelationEntity entity) {
    if (entity.sourceType == MilestoneSourceType.manual) {
      if (entity.sourceId != null) {
        throw ArgumentError.value(
          entity.sourceId,
          'sourceId',
          'Manual milestone sources must not have a source id.',
        );
      }
      return;
    }
    if (entity.sourceId == null) {
      throw ArgumentError.value(
        entity.sourceId,
        'sourceId',
        'Non-manual milestone sources require a source id.',
      );
    }
  }
}
