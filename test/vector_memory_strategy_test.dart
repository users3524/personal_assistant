import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/vector_memory_strategy.dart';

void main() {
  group('VectorMemoryStrategy', () {
    test('defaults to local SQLite BLOB and Dart linear cosine retrieval', () {
      const strategy = VectorMemoryStrategy();

      expect(strategy.enabled, false);
      expect(strategy.storageBackend, VectorStorageBackend.sqliteBlob);
      expect(strategy.retrievalMode, VectorRetrievalMode.dartLinearCosine);
      expect(strategy.linearScanThreshold, 10000);
      expect(strategy.rebuildBatchSize, 128);
      expect(
        strategy.evaluateIndex(null).status,
        VectorMemoryIndexStatus.disabled,
      );
    });

    test('serializes embedding model, dimension and rebuild policy', () {
      const strategy = VectorMemoryStrategy(
        enabled: true,
        embeddingProfile: EmbeddingProfile(
          provider: 'OpenAI',
          model: 'text-embedding-3-small',
          dimension: 1536,
        ),
        linearScanThreshold: 8000,
        rebuildBatchSize: 64,
      );

      final restored = VectorMemoryStrategy.fromJson(strategy.toJson());

      expect(restored.enabled, true);
      expect(restored.storageBackend, VectorStorageBackend.sqliteBlob);
      expect(restored.retrievalMode, VectorRetrievalMode.dartLinearCosine);
      expect(restored.embeddingProfile.provider, 'OpenAI');
      expect(restored.embeddingProfile.model, 'text-embedding-3-small');
      expect(restored.embeddingProfile.dimension, 1536);
      expect(restored.linearScanThreshold, 8000);
      expect(restored.rebuildBatchSize, 64);
    });

    test('requires a configured embedding profile before search', () {
      const strategy = VectorMemoryStrategy(enabled: true);

      final decision = strategy.evaluateIndex(null);

      expect(decision.canSearch, false);
      expect(decision.shouldRebuild, false);
      expect(decision.status, VectorMemoryIndexStatus.disabled);
      expect(decision.reason, contains('embedding'));
    });

    test('triggers rebuild when index is missing or incompatible', () {
      const strategy = VectorMemoryStrategy(
        enabled: true,
        embeddingProfile: EmbeddingProfile(
          provider: 'OpenAI',
          model: 'text-embedding-3-small',
          dimension: 1536,
        ),
      );

      final missing = strategy.evaluateIndex(null);
      final dimensionMismatch = strategy.evaluateIndex(
        const VectorIndexMetadata(
          embeddingProfile: EmbeddingProfile(
            provider: 'OpenAI',
            model: 'text-embedding-3-small',
            dimension: 1024,
          ),
        ),
      );
      final modelMismatch = strategy.evaluateIndex(
        const VectorIndexMetadata(
          embeddingProfile: EmbeddingProfile(
            provider: 'OpenAI',
            model: 'text-embedding-3-large',
            dimension: 1536,
          ),
        ),
      );

      expect(missing.status, VectorMemoryIndexStatus.missingIndex);
      expect(missing.shouldRebuild, true);
      expect(
        dimensionMismatch.status,
        VectorMemoryIndexStatus.dimensionMismatch,
      );
      expect(dimensionMismatch.canSearch, false);
      expect(dimensionMismatch.shouldRebuild, true);
      expect(modelMismatch.status, VectorMemoryIndexStatus.modelMismatch);
      expect(modelMismatch.shouldRebuild, true);
    });

    test('allows search only when storage, model and dimension match', () {
      const strategy = VectorMemoryStrategy(
        enabled: true,
        embeddingProfile: EmbeddingProfile(
          provider: 'OpenAI',
          model: 'text-embedding-3-small',
          dimension: 1536,
        ),
      );

      final decision = strategy.evaluateIndex(
        const VectorIndexMetadata(
          embeddingProfile: EmbeddingProfile(
            provider: 'OpenAI',
            model: 'text-embedding-3-small',
            dimension: 1536,
          ),
        ),
      );

      expect(decision.status, VectorMemoryIndexStatus.ready);
      expect(decision.canSearch, true);
      expect(decision.shouldRebuild, false);
      expect(decision.reason, isEmpty);
    });

    test('allows blank stored provider when model and dimension match', () {
      const strategy = VectorMemoryStrategy(
        enabled: true,
        embeddingProfile: EmbeddingProfile(
          provider: 'OpenAI',
          model: 'text-embedding-3-small',
          dimension: 1536,
        ),
      );

      final decision = strategy.evaluateIndex(
        const VectorIndexMetadata(
          embeddingProfile: EmbeddingProfile(
            model: 'text-embedding-3-small',
            dimension: 1536,
          ),
        ),
      );

      expect(decision.status, VectorMemoryIndexStatus.ready);
      expect(decision.canSearch, true);
    });
  });
}
