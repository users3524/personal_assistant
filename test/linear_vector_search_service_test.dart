import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/vector_memory_strategy.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/milestone_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/vector_embedding_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/linear_vector_search_service.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/vector_data_codec.dart';

void main() {
  group('LinearVectorSearchService', () {
    const service = LinearVectorSearchService();

    test('orders candidates by cosine similarity using Dart linear scan', () {
      final now = DateTime(2026, 6, 21, 9);
      final result = service.search(
        queryVectorData: _vector([1, 0, 0]),
        dimension: 3,
        topK: 2,
        candidates: [
          _embedding(
            id: 1,
            sourceId: 1,
            vectorData: _vector([0, 1, 0]),
            now: now,
          ),
          _embedding(
            id: 2,
            sourceId: 2,
            vectorData: _vector([1, 0, 0]),
            now: now,
          ),
          _embedding(
            id: 3,
            sourceId: 3,
            vectorData: _vector([1, 1, 0]),
            now: now,
          ),
        ],
      );

      expect(result.matches.map((match) => match.embedding.id), [2, 3]);
      expect(result.matches.first.score, closeTo(1, 0.000001));
      expect(result.matches.last.score, closeTo(0.707106, 0.00001));
      expect(
        result.benchmark.mode,
        VectorRetrievalMode.dartLinearCosine.storageValue,
      );
      expect(result.benchmark.candidateCount, 3);
      expect(result.benchmark.dimension, 3);
      expect(result.benchmark.elapsedMicroseconds, greaterThanOrEqualTo(0));
    });

    test('uses stable id ordering when scores tie', () {
      final now = DateTime(2026, 6, 21, 9);
      final result = service.search(
        queryVectorData: _vector([1, 0]),
        dimension: 2,
        candidates: [
          _embedding(id: 5, sourceId: 5, vectorData: _vector([1, 0]), now: now),
          _embedding(id: 3, sourceId: 3, vectorData: _vector([1, 0]), now: now),
        ],
      );

      expect(result.matches.map((match) => match.embedding.id), [3, 5]);
    });

    test('rejects invalid topK and mismatched vector dimensions', () {
      final now = DateTime(2026, 6, 21, 9);

      expect(
        () => service.search(
          queryVectorData: _vector([1, 0]),
          dimension: 2,
          topK: 0,
          candidates: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => service.search(
          queryVectorData: _vector([1, 0]),
          dimension: 2,
          candidates: [
            _embedding(
              id: 1,
              sourceId: 1,
              vectorData: _vector([1, 0, 0]),
              now: now,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

VectorEmbeddingEntity _embedding({
  required int id,
  required int sourceId,
  required Uint8List vectorData,
  required DateTime now,
}) {
  return VectorEmbeddingEntity(
    id: id,
    sourceType: MilestoneSourceType.todo,
    sourceId: sourceId,
    embeddingModel: 'text-embedding-3-small',
    dimension: vectorData.length ~/ VectorDataCodec.bytesPerValue,
    vectorData: vectorData,
    createdAt: now,
    updatedAt: now,
  );
}

Uint8List _vector(List<double> values) {
  return const VectorDataCodec().encodeNormalized(values);
}
