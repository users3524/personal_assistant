import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/review_generation_job_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/repositories/review_generation_job_store.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/review_catch_up_guard.dart';

void main() {
  group('ReviewCatchUpGuard', () {
    test('creates a pending job for yesterday when missing', () async {
      final store = _FakeReviewGenerationJobStore();
      final guard = ReviewCatchUpGuard(
        store,
        now: () => DateTime(2026, 6, 21, 8),
      );

      final result = await guard.ensureYesterdayJob();

      expect(result.targetDate, '2026-06-20');
      expect(result.shouldRunCatchUp, true);
      expect(result.job.targetDate, '2026-06-20');
      expect(result.job.status, ReviewGenerationJobStatus.pending);
      expect(store.jobs, contains('2026-06-20'));
    });

    test('skips catch-up when yesterday already succeeded', () async {
      final store = _FakeReviewGenerationJobStore();
      store.jobs['2026-06-20'] = _job(
        '2026-06-20',
        ReviewGenerationJobStatus.success,
      );
      final guard = ReviewCatchUpGuard(
        store,
        now: () => DateTime(2026, 6, 21, 8),
      );

      final result = await guard.ensureYesterdayJob();

      expect(result.shouldRunCatchUp, false);
      expect(result.job.status, ReviewGenerationJobStatus.success);
    });

    test('resets failed job to pending for foreground catch-up', () async {
      final store = _FakeReviewGenerationJobStore();
      store.jobs['2026-06-20'] = _job(
        '2026-06-20',
        ReviewGenerationJobStatus.failed,
        failureReason: 'network',
        processedAt: DateTime(2026, 6, 21, 2),
      );
      final guard = ReviewCatchUpGuard(
        store,
        now: () => DateTime(2026, 6, 21, 8),
      );

      final result = await guard.ensureYesterdayJob();

      expect(result.shouldRunCatchUp, true);
      expect(result.job.status, ReviewGenerationJobStatus.pending);
      expect(result.job.failureReason, null);
      expect(result.job.processedAt, null);
    });
  });
}

class _FakeReviewGenerationJobStore implements ReviewGenerationJobStore {
  final jobs = <String, ReviewGenerationJobEntity>{};

  @override
  Future<ReviewGenerationJobEntity?> getByTargetDate(String targetDate) async {
    return jobs[targetDate];
  }

  @override
  Future<ReviewGenerationJobEntity> getOrCreatePending(
    String targetDate, {
    DateTime? now,
  }) async {
    return jobs.putIfAbsent(
      targetDate,
      () => ReviewGenerationJobEntity(
        id: jobs.length + 1,
        targetDate: targetDate,
        createdAt: now ?? DateTime(2026, 6, 21),
      ),
    );
  }

  @override
  Future<void> markPending(String targetDate, {DateTime? now}) async {
    final existing = await getOrCreatePending(targetDate, now: now);
    jobs[targetDate] = ReviewGenerationJobEntity(
      id: existing.id,
      targetDate: existing.targetDate,
      createdAt: existing.createdAt,
    );
  }
}

ReviewGenerationJobEntity _job(
  String targetDate,
  ReviewGenerationJobStatus status, {
  String? failureReason,
  DateTime? processedAt,
}) {
  return ReviewGenerationJobEntity(
    id: 1,
    targetDate: targetDate,
    status: status,
    failureReason: failureReason,
    processedAt: processedAt,
    createdAt: DateTime(2026, 6, 21),
  );
}
