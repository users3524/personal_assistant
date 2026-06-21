import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/vector_embedding_dao.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/milestone_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/vector_embedding_entity.dart';

void main() {
  group('VectorEmbeddingDao', () {
    late AppDatabase db;
    late VectorEmbeddingDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = VectorEmbeddingDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'upserts and queries embeddings by source and model metadata',
      () async {
        final now = DateTime(2026, 6, 21, 9);
        final created = await dao.upsert(
          _embedding(
            now: now,
            sourceType: MilestoneSourceType.dailyReview,
            sourceId: 7,
            vectorData: Uint8List.fromList([1, 2, 3, 4]),
          ),
        );

        final bySource = await dao.getBySource(
          sourceType: MilestoneSourceType.dailyReview,
          sourceId: 7,
          embeddingModel: 'text-embedding-3-small',
          dimension: 4,
        );
        final byModel = await dao.getByModel(
          embeddingModel: 'text-embedding-3-small',
          dimension: 4,
        );

        expect(created.id, isNotNull);
        expect(bySource?.sourceType, MilestoneSourceType.dailyReview);
        expect(bySource?.sourceId, 7);
        expect(bySource?.vectorData, [1, 2, 3, 4]);
        expect(bySource?.storageBackend, 'sqlite_blob');
        expect(bySource?.encodingVersion, 'float32_le_v1');
        expect(byModel.single.id, bySource?.id);
      },
    );

    test('replaces the same source model and dimension record', () async {
      final now = DateTime(2026, 6, 21, 9);
      await dao.upsert(
        _embedding(
          now: now,
          sourceType: MilestoneSourceType.todo,
          sourceId: 1,
          vectorData: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );
      await dao.upsert(
        _embedding(
          now: now.add(const Duration(minutes: 1)),
          sourceType: MilestoneSourceType.todo,
          sourceId: 1,
          vectorData: Uint8List.fromList([4, 3, 2, 1]),
          contentHash: 'changed',
        ),
      );

      final rows = await dao.getByModel(
        embeddingModel: 'text-embedding-3-small',
        dimension: 4,
      );

      expect(rows, hasLength(1));
      expect(rows.single.vectorData, [4, 3, 2, 1]);
      expect(rows.single.contentHash, 'changed');
    });

    test('enforces source id and vector metadata rules', () async {
      final now = DateTime(2026, 6, 21, 9);

      expect(
        () => dao.upsert(
          _embedding(now: now, sourceType: MilestoneSourceType.todo),
        ),
        throwsArgumentError,
      );
      expect(
        () => dao.upsert(
          _embedding(
            now: now,
            sourceType: MilestoneSourceType.manual,
            sourceId: 1,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => dao.upsert(_embedding(now: now, dimension: 0, sourceId: 1)),
        throwsArgumentError,
      );
      expect(
        () => dao.upsert(
          _embedding(now: now, vectorData: Uint8List(0), sourceId: 1),
        ),
        throwsArgumentError,
      );
    });

    test('deletes embeddings by source', () async {
      final now = DateTime(2026, 6, 21, 9);
      await dao.upsert(
        _embedding(now: now, sourceType: MilestoneSourceType.todo, sourceId: 1),
      );
      await dao.upsert(
        _embedding(now: now, sourceType: MilestoneSourceType.todo, sourceId: 2),
      );

      final deleted = await dao.deleteBySource(
        sourceType: MilestoneSourceType.todo,
        sourceId: 1,
      );
      final rows = await dao.getByModel(
        embeddingModel: 'text-embedding-3-small',
        dimension: 4,
      );

      expect(deleted, 1);
      expect(rows.single.sourceId, 2);
    });

    test('replaces manual source embeddings with null source id', () async {
      final now = DateTime(2026, 6, 21, 9);
      await dao.upsert(
        _embedding(
          now: now,
          sourceType: MilestoneSourceType.manual,
          vectorData: Uint8List.fromList([1, 1, 1, 1]),
        ),
      );
      await dao.upsert(
        _embedding(
          now: now.add(const Duration(minutes: 1)),
          sourceType: MilestoneSourceType.manual,
          vectorData: Uint8List.fromList([2, 2, 2, 2]),
        ),
      );

      final rows = await dao.getByModel(
        embeddingModel: 'text-embedding-3-small',
        dimension: 4,
      );

      expect(rows, hasLength(1));
      expect(rows.single.sourceType, MilestoneSourceType.manual);
      expect(rows.single.sourceId, null);
      expect(rows.single.vectorData, [2, 2, 2, 2]);
    });
  });
}

VectorEmbeddingEntity _embedding({
  required DateTime now,
  MilestoneSourceType sourceType = MilestoneSourceType.todo,
  int? sourceId,
  String embeddingModel = 'text-embedding-3-small',
  int dimension = 4,
  Uint8List? vectorData,
  String? contentHash,
}) {
  return VectorEmbeddingEntity(
    sourceType: sourceType,
    sourceId: sourceId,
    embeddingModel: embeddingModel,
    dimension: dimension,
    vectorData: vectorData ?? Uint8List.fromList([0, 0, 0, 1]),
    contentHash: contentHash,
    createdAt: now,
    updatedAt: now,
  );
}
