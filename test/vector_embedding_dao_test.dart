import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/vector_memory_strategy.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/vector_embedding_dao.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/milestone_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/vector_embedding_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/vector_data_codec.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/vector_search_guard.dart';

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
            vectorData: _vector([1, 0, 0, 0]),
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
        expect(_decode(bySource!.vectorData), [1, 0, 0, 0]);
        expect(bySource.storageBackend, 'sqlite_blob');
        expect(bySource.encodingVersion, 'float32_le_v1');
        expect(byModel.single.id, bySource.id);
      },
    );

    test('replaces the same source model and dimension record', () async {
      final now = DateTime(2026, 6, 21, 9);
      await dao.upsert(
        _embedding(
          now: now,
          sourceType: MilestoneSourceType.todo,
          sourceId: 1,
          vectorData: _vector([1, 0, 0, 0]),
        ),
      );
      await dao.upsert(
        _embedding(
          now: now.add(const Duration(minutes: 1)),
          sourceType: MilestoneSourceType.todo,
          sourceId: 1,
          vectorData: _vector([0, 1, 0, 0]),
          contentHash: 'changed',
        ),
      );

      final rows = await dao.getByModel(
        embeddingModel: 'text-embedding-3-small',
        dimension: 4,
      );

      expect(rows, hasLength(1));
      expect(_decode(rows.single.vectorData), [0, 1, 0, 0]);
      expect(rows.single.contentHash, 'changed');
    });

    test('reads current index metadata for search guard', () async {
      final now = DateTime(2026, 6, 21, 9);
      expect(await dao.getIndexMetadata(), null);

      await dao.upsert(
        _embedding(
          now: now,
          sourceType: MilestoneSourceType.dailyReview,
          sourceId: 7,
          vectorData: _vector([1, 0, 0, 0]),
        ),
      );

      final metadata = await dao.getIndexMetadata();

      expect(metadata?.storageBackend.storageValue, 'sqlite_blob');
      expect(metadata?.embeddingProfile.model, 'text-embedding-3-small');
      expect(metadata?.embeddingProfile.dimension, 4);
    });

    test('searches matching vectors with guard and benchmark', () async {
      final now = DateTime(2026, 6, 21, 9);
      await dao.upsert(
        _embedding(
          now: now,
          sourceType: MilestoneSourceType.todo,
          sourceId: 1,
          vectorData: _vector([1, 0, 0, 0]),
        ),
      );
      await dao.upsert(
        _embedding(
          now: now,
          sourceType: MilestoneSourceType.todo,
          sourceId: 2,
          vectorData: _vector([0, 1, 0, 0]),
        ),
      );

      final result = await dao.searchLinear(
        queryVectorData: _vector([1, 0, 0, 0]),
        topK: 1,
        strategy: _strategy(model: 'text-embedding-3-small', dimension: 4),
      );

      expect(result.matches.single.embedding.sourceId, 1);
      expect(result.matches.single.score, closeTo(1, 0.000001));
      expect(result.benchmark.mode, 'dart_linear_cosine');
      expect(result.benchmark.candidateCount, 2);
      expect(result.benchmark.dimension, 4);
    });

    test(
      'rejects linear search when model or dimension does not match',
      () async {
        final now = DateTime(2026, 6, 21, 9);
        await dao.upsert(
          _embedding(
            now: now,
            sourceType: MilestoneSourceType.todo,
            sourceId: 1,
          ),
        );

        await expectLater(
          dao.searchLinear(
            queryVectorData: _vector([1, 0, 0, 0]),
            strategy: _strategy(model: 'other-embedding-model', dimension: 4),
          ),
          throwsA(isA<VectorSearchRejectedException>()),
        );
        await expectLater(
          dao.searchLinear(
            queryVectorData: _vector([1, 0, 0]),
            strategy: _strategy(model: 'text-embedding-3-small', dimension: 3),
          ),
          throwsA(isA<VectorSearchRejectedException>()),
        );
      },
    );

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
      expect(
        () => dao.upsert(
          _embedding(
            now: now,
            vectorData: Uint8List.fromList([1, 2, 3, 4]),
            sourceId: 1,
          ),
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
          vectorData: _vector([1, 0, 0, 0]),
        ),
      );
      await dao.upsert(
        _embedding(
          now: now.add(const Duration(minutes: 1)),
          sourceType: MilestoneSourceType.manual,
          vectorData: _vector([0, 0, 1, 0]),
        ),
      );

      final rows = await dao.getByModel(
        embeddingModel: 'text-embedding-3-small',
        dimension: 4,
      );

      expect(rows, hasLength(1));
      expect(rows.single.sourceType, MilestoneSourceType.manual);
      expect(rows.single.sourceId, null);
      expect(_decode(rows.single.vectorData), [0, 0, 1, 0]);
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
    vectorData: vectorData ?? _vector([0, 0, 0, 1]),
    contentHash: contentHash,
    createdAt: now,
    updatedAt: now,
  );
}

Uint8List _vector(List<double> values) {
  return const VectorDataCodec().encodeNormalized(values);
}

List<double> _decode(Uint8List bytes) {
  return const VectorDataCodec().decode(bytes, dimension: 4);
}

VectorMemoryStrategy _strategy({
  required String model,
  required int dimension,
}) {
  return VectorMemoryStrategy(
    enabled: true,
    embeddingProfile: EmbeddingProfile(
      provider: 'OpenAI',
      model: model,
      dimension: dimension,
    ),
  );
}
