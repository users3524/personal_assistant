import '../../../../core/ai/vector_memory_strategy.dart';

class VectorSearchGuard {
  final VectorMemoryStrategy strategy;

  const VectorSearchGuard({required this.strategy});

  VectorMemoryIndexDecision evaluate(VectorIndexMetadata? currentIndex) {
    return strategy.evaluateIndex(currentIndex);
  }

  void assertCanSearch(VectorIndexMetadata? currentIndex) {
    final decision = evaluate(currentIndex);
    if (decision.canSearch) return;
    throw VectorSearchRejectedException(decision);
  }
}

class VectorSearchRejectedException implements Exception {
  final VectorMemoryIndexDecision decision;

  const VectorSearchRejectedException(this.decision);

  @override
  String toString() => 'VectorSearchRejectedException: ${decision.reason}';
}
