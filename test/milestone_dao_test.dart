import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/milestone_dao.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/milestone_entity.dart';

void main() {
  group('MilestoneDao', () {
    late AppDatabase db;
    late MilestoneDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = MilestoneDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates milestones with multiple typed source relations', () async {
      final now = DateTime(2026, 6, 21, 9);
      final created = await dao.createMilestoneWithRelations(
        _milestone(
          title: '发布深夜复盘引擎',
          occurredAt: DateTime(2026, 6, 20),
          now: now,
        ),
        [
          _relation(
            sourceType: MilestoneSourceType.todo,
            sourceId: 7,
            note: '实现任务',
            now: now,
          ),
          _relation(
            sourceType: MilestoneSourceType.dailyReview,
            sourceId: 3,
            note: '日报证据',
            now: now.add(const Duration(minutes: 1)),
          ),
        ],
      );

      final milestones = await dao.getMilestones(confirmedOnly: false);
      final relations = await dao.getRelationsForMilestone(created.id!);

      expect(created.id, isNotNull);
      expect(milestones.single.title, '发布深夜复盘引擎');
      expect(milestones.single.isConfirmedByUser, false);
      expect(relations.map((relation) => relation.sourceType), [
        MilestoneSourceType.todo,
        MilestoneSourceType.dailyReview,
      ]);
      expect(relations.map((relation) => relation.sourceId), [7, 3]);
    });

    test('queries milestones by source and confirmation status', () async {
      final now = DateTime(2026, 6, 21, 9);
      await dao.createMilestoneWithRelations(
        _milestone(
          title: '确认高光',
          occurredAt: DateTime(2026, 6, 20),
          confirmed: true,
          now: now,
        ),
        [
          _relation(
            sourceType: MilestoneSourceType.pattingLog,
            sourceId: 42,
            now: now,
          ),
        ],
      );
      await dao.createMilestoneWithRelations(
        _milestone(title: '待确认高光', occurredAt: DateTime(2026, 6, 19), now: now),
        [_relation(sourceType: MilestoneSourceType.manual, now: now)],
      );

      final confirmed = await dao.getMilestones(confirmedOnly: true);
      final fromPattingLog = await dao.getMilestonesBySource(
        sourceType: MilestoneSourceType.pattingLog,
        sourceId: 42,
      );
      final manual = await dao.getMilestonesBySource(
        sourceType: MilestoneSourceType.manual,
      );

      expect(confirmed.map((milestone) => milestone.title), ['确认高光']);
      expect(fromPattingLog.map((milestone) => milestone.title), ['确认高光']);
      expect(manual.map((milestone) => milestone.title), ['待确认高光']);
    });

    test('enforces manual and typed source id rules', () async {
      final now = DateTime(2026, 6, 21, 9);
      final milestone = await dao.insertMilestone(
        _milestone(title: '规则校验', occurredAt: now, now: now),
      );

      expect(
        () => dao.insertRelation(
          _relation(
            milestoneId: milestone.id,
            sourceType: MilestoneSourceType.manual,
            sourceId: 1,
            now: now,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => dao.insertRelation(
          _relation(
            milestoneId: milestone.id,
            sourceType: MilestoneSourceType.todo,
            now: now,
          ),
        ),
        throwsArgumentError,
      );

      await expectLater(
        db.customStatement(
          '''
INSERT INTO milestone_relations (
  milestone_id, source_type, source_id, created_at
) VALUES (?, 'manual', 99, ?)
''',
          [milestone.id!, now.millisecondsSinceEpoch ~/ 1000],
        ),
        throwsA(anything),
      );
    });

    test('cleans source relations by source', () async {
      final now = DateTime(2026, 6, 21, 9);
      final milestone = await dao.createMilestoneWithRelations(
        _milestone(title: '清理关联', occurredAt: now, now: now),
        [
          _relation(
            sourceType: MilestoneSourceType.todo,
            sourceId: 7,
            now: now,
          ),
          _relation(
            sourceType: MilestoneSourceType.dailyReview,
            sourceId: 3,
            now: now,
          ),
        ],
      );

      final deleted = await dao.deleteRelationsBySource(
        sourceType: MilestoneSourceType.todo,
        sourceId: 7,
      );
      final remaining = await dao.getRelationsForMilestone(milestone.id!);

      expect(deleted, 1);
      expect(remaining.single.sourceType, MilestoneSourceType.dailyReview);
    });
  });
}

MilestoneEntity _milestone({
  required String title,
  required DateTime occurredAt,
  required DateTime now,
  bool confirmed = false,
}) {
  return MilestoneEntity(
    title: title,
    description: 'milestone description',
    occurredAt: occurredAt,
    importanceScore: confirmed ? 5 : 3,
    isAiGenerated: true,
    isConfirmedByUser: confirmed,
    createdAt: now,
    updatedAt: now,
  );
}

MilestoneRelationEntity _relation({
  int? milestoneId,
  required MilestoneSourceType sourceType,
  int? sourceId,
  String? note,
  required DateTime now,
}) {
  return MilestoneRelationEntity(
    milestoneId: milestoneId ?? 0,
    sourceType: sourceType,
    sourceId: sourceId,
    note: note,
    createdAt: now,
  );
}
