import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/vector_memory_strategy.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/vector_search_guard.dart';

void main() {
  group('VectorSearchGuard', () {
    test('allows search when index metadata matches strategy', () {
      final guard = VectorSearchGuard(strategy: _strategy());

      final decision = guard.evaluate(
        const VectorIndexMetadata(
          embeddingProfile: EmbeddingProfile(
            model: 'text-embedding-3-small',
            dimension: 4,
          ),
        ),
      );

      expect(decision.canSearch, true);
      expect(decision.shouldRebuild, false);
      expect(() => guard.assertCanSearch(_matchingIndex()), returnsNormally);
    });

    test('rejects missing index and asks for rebuild', () {
      final guard = VectorSearchGuard(strategy: _strategy());

      final decision = guard.evaluate(null);

      expect(decision.canSearch, false);
      expect(decision.shouldRebuild, true);
      expect(decision.status, VectorMemoryIndexStatus.missingIndex);
      expect(
        () => guard.assertCanSearch(null),
        throwsA(
          isA<VectorSearchRejectedException>().having(
            (error) => error.decision.shouldRebuild,
            'shouldRebuild',
            true,
          ),
        ),
      );
    });

    test('rejects incompatible model and dimension before similarity math', () {
      final guard = VectorSearchGuard(strategy: _strategy());

      final modelMismatch = guard.evaluate(
        const VectorIndexMetadata(
          embeddingProfile: EmbeddingProfile(
            model: 'text-embedding-3-large',
            dimension: 4,
          ),
        ),
      );
      final dimensionMismatch = guard.evaluate(
        const VectorIndexMetadata(
          embeddingProfile: EmbeddingProfile(
            model: 'text-embedding-3-small',
            dimension: 3,
          ),
        ),
      );

      expect(modelMismatch.canSearch, false);
      expect(modelMismatch.shouldRebuild, true);
      expect(modelMismatch.status, VectorMemoryIndexStatus.modelMismatch);
      expect(dimensionMismatch.canSearch, false);
      expect(dimensionMismatch.shouldRebuild, true);
      expect(
        dimensionMismatch.status,
        VectorMemoryIndexStatus.dimensionMismatch,
      );
    });
  });
}

VectorMemoryStrategy _strategy() {
  return const VectorMemoryStrategy(
    enabled: true,
    embeddingProfile: EmbeddingProfile(
      provider: 'OpenAI',
      model: 'text-embedding-3-small',
      dimension: 4,
    ),
  );
}

VectorIndexMetadata _matchingIndex() {
  return const VectorIndexMetadata(
    embeddingProfile: EmbeddingProfile(
      model: 'text-embedding-3-small',
      dimension: 4,
    ),
  );
}
