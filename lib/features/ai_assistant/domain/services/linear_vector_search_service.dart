import 'dart:typed_data';

import '../../../../core/ai/vector_memory_strategy.dart';
import '../entities/vector_embedding_entity.dart';
import 'vector_data_codec.dart';

class VectorSearchMatch {
  final VectorEmbeddingEntity embedding;
  final double score;

  const VectorSearchMatch({required this.embedding, required this.score});
}

class VectorSearchBenchmark {
  final String mode;
  final int candidateCount;
  final int dimension;
  final int elapsedMicroseconds;

  const VectorSearchBenchmark({
    required this.mode,
    required this.candidateCount,
    required this.dimension,
    required this.elapsedMicroseconds,
  });
}

class VectorSearchResult {
  final List<VectorSearchMatch> matches;
  final VectorSearchBenchmark benchmark;

  const VectorSearchResult({required this.matches, required this.benchmark});
}

class LinearVectorSearchService {
  final VectorDataCodec _codec;

  const LinearVectorSearchService({
    VectorDataCodec codec = const VectorDataCodec(),
  }) : _codec = codec;

  VectorSearchResult search({
    required Uint8List queryVectorData,
    required List<VectorEmbeddingEntity> candidates,
    required int dimension,
    int topK = 5,
  }) {
    if (topK <= 0) {
      throw ArgumentError.value(topK, 'topK', 'topK must be positive.');
    }

    final stopwatch = Stopwatch()..start();
    final query = _codec.decode(queryVectorData, dimension: dimension);
    final matches = <VectorSearchMatch>[];

    for (final candidate in candidates) {
      final vector = _codec.decode(candidate.vectorData, dimension: dimension);
      matches.add(
        VectorSearchMatch(embedding: candidate, score: _dot(query, vector)),
      );
    }

    matches.sort(_compareMatches);
    final kept = matches.take(topK).toList(growable: false);
    stopwatch.stop();

    return VectorSearchResult(
      matches: List.unmodifiable(kept),
      benchmark: VectorSearchBenchmark(
        mode: VectorRetrievalMode.dartLinearCosine.storageValue,
        candidateCount: candidates.length,
        dimension: dimension,
        elapsedMicroseconds: stopwatch.elapsedMicroseconds,
      ),
    );
  }

  double _dot(List<double> a, List<double> b) {
    var score = 0.0;
    for (var i = 0; i < a.length; i++) {
      score += a[i] * b[i];
    }
    return score;
  }

  int _compareMatches(VectorSearchMatch a, VectorSearchMatch b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;

    final aId = a.embedding.id ?? 0;
    final bId = b.embedding.id ?? 0;
    final idCompare = aId.compareTo(bId);
    if (idCompare != 0) return idCompare;

    final typeCompare = a.embedding.sourceType.storageValue.compareTo(
      b.embedding.sourceType.storageValue,
    );
    if (typeCompare != 0) return typeCompare;

    return (a.embedding.sourceId ?? -1).compareTo(b.embedding.sourceId ?? -1);
  }
}
