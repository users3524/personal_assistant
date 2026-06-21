import '../../../../core/ai/vector_memory_strategy.dart';

enum VectorSearchExecutionMode {
  foregroundLinearScan,
  filteredIsolateLinearScan,
}

class VectorSearchFilters {
  final int? year;
  final String? compassDimensionId;

  const VectorSearchFilters({this.year, this.compassDimensionId});

  bool get hasPartitionFilter =>
      year != null ||
      (compassDimensionId != null && compassDimensionId!.trim().isNotEmpty);
}

class VectorSearchExecutionPlan {
  final VectorSearchExecutionMode mode;
  final bool requiresPartitionFilter;
  final bool shouldRunInIsolate;
  final String reason;

  const VectorSearchExecutionPlan({
    required this.mode,
    required this.requiresPartitionFilter,
    required this.shouldRunInIsolate,
    required this.reason,
  });
}

class VectorSearchExecutionPlanner {
  final VectorMemoryStrategy strategy;

  const VectorSearchExecutionPlanner({required this.strategy});

  VectorSearchExecutionPlan plan({
    required int candidateCount,
    VectorSearchFilters filters = const VectorSearchFilters(),
  }) {
    if (candidateCount < 0) {
      throw ArgumentError.value(
        candidateCount,
        'candidateCount',
        'candidateCount must not be negative.',
      );
    }

    if (candidateCount <= strategy.linearScanThreshold) {
      return const VectorSearchExecutionPlan(
        mode: VectorSearchExecutionMode.foregroundLinearScan,
        requiresPartitionFilter: false,
        shouldRunInIsolate: false,
        reason: '候选数量未超过线性扫描阈值，可在当前 Isolate 执行。',
      );
    }

    if (!filters.hasPartitionFilter) {
      return const VectorSearchExecutionPlan(
        mode: VectorSearchExecutionMode.filteredIsolateLinearScan,
        requiresPartitionFilter: true,
        shouldRunInIsolate: true,
        reason: '候选数量超过阈值，需先按年份或人生罗盘维度过滤，并迁移到 Isolate 计算。',
      );
    }

    return const VectorSearchExecutionPlan(
      mode: VectorSearchExecutionMode.filteredIsolateLinearScan,
      requiresPartitionFilter: false,
      shouldRunInIsolate: true,
      reason: '候选数量超过阈值，已提供分区过滤，应迁移到 Isolate 计算。',
    );
  }
}
