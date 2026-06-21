import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/vector_memory_strategy.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/vector_search_execution_planner.dart';

void main() {
  group('VectorSearchExecutionPlanner', () {
    test('keeps small vector sets on foreground linear scan', () {
      final planner = VectorSearchExecutionPlanner(strategy: _strategy());

      final plan = planner.plan(candidateCount: 10000);

      expect(plan.mode, VectorSearchExecutionMode.foregroundLinearScan);
      expect(plan.requiresPartitionFilter, false);
      expect(plan.shouldRunInIsolate, false);
    });

    test('requires year or compass partition above threshold', () {
      final planner = VectorSearchExecutionPlanner(strategy: _strategy());

      final plan = planner.plan(candidateCount: 10001);

      expect(plan.mode, VectorSearchExecutionMode.filteredIsolateLinearScan);
      expect(plan.requiresPartitionFilter, true);
      expect(plan.shouldRunInIsolate, true);
      expect(plan.reason, contains('年份'));
      expect(plan.reason, contains('人生罗盘'));
    });

    test('uses isolate when large vector sets have partition filters', () {
      final planner = VectorSearchExecutionPlanner(strategy: _strategy());

      final byYear = planner.plan(
        candidateCount: 10001,
        filters: const VectorSearchFilters(year: 2026),
      );
      final byCompass = planner.plan(
        candidateCount: 10001,
        filters: const VectorSearchFilters(compassDimensionId: 'career'),
      );

      expect(byYear.requiresPartitionFilter, false);
      expect(byYear.shouldRunInIsolate, true);
      expect(byCompass.requiresPartitionFilter, false);
      expect(byCompass.shouldRunInIsolate, true);
    });

    test('honors configured linear scan threshold', () {
      const planner = VectorSearchExecutionPlanner(
        strategy: VectorMemoryStrategy(linearScanThreshold: 3),
      );

      expect(
        planner.plan(candidateCount: 3).mode,
        VectorSearchExecutionMode.foregroundLinearScan,
      );
      expect(planner.plan(candidateCount: 4).shouldRunInIsolate, true);
    });

    test('rejects negative candidate counts', () {
      final planner = VectorSearchExecutionPlanner(strategy: _strategy());

      expect(() => planner.plan(candidateCount: -1), throwsArgumentError);
    });
  });
}

VectorMemoryStrategy _strategy() {
  return const VectorMemoryStrategy(linearScanThreshold: 10000);
}
