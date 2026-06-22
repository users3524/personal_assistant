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

    test('does not reset failed job after three structured calls', () async {
      final store = _FakeReviewGenerationJobStore();
      store.jobs['2026-06-20'] = _job(
        '2026-06-20',
        ReviewGenerationJobStatus.failed,
        attemptCount: 3,
        failureReason: 'structured output exhausted',
        processedAt: DateTime(2026, 6, 21, 2),
      );
      final guard = ReviewCatchUpGuard(
        store,
        now: () => DateTime(2026, 6, 21, 8),
      );

      final result = await guard.ensureYesterdayJob();

      expect(result.shouldRunCatchUp, false);
      expect(result.job.status, ReviewGenerationJobStatus.failed);
      expect(result.job.attemptCount, 3);
      expect(result.job.failureReason, 'structured output exhausted');
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

  @override
  Future<int> incrementAttempt(String targetDate, {DateTime? now}) async {
    final existing = await getOrCreatePending(targetDate, now: now);
    final next = existing.copyWith(attemptCount: existing.attemptCount + 1);
    jobs[targetDate] = next;
    return next.attemptCount;
  }

  @override
  Future<void> saveRawAssetsDump(
    String targetDate, {
    required String rawAssetsDump,
    DateTime? now,
  }) async {
    final existing = await getOrCreatePending(targetDate, now: now);
    jobs[targetDate] = ReviewGenerationJobEntity(
      id: existing.id,
      targetDate: existing.targetDate,
      status: ReviewGenerationJobStatus.pending,
      rawAssetsDump: rawAssetsDump,
      attemptCount: existing.attemptCount,
      createdAt: existing.createdAt,
    );
  }

  @override
  Future<void> markSuccess(
    String targetDate, {
    String? rawAssetsDump,
    DateTime? processedAt,
  }) async {
    final existing = await getOrCreatePending(targetDate, now: processedAt);
    jobs[targetDate] = ReviewGenerationJobEntity(
      id: existing.id,
      targetDate: existing.targetDate,
      status: ReviewGenerationJobStatus.success,
      attemptCount: existing.attemptCount,
      rawAssetsDump: rawAssetsDump,
      processedAt: processedAt,
      createdAt: existing.createdAt,
    );
  }

  @override
  Future<void> markFailed(
    String targetDate, {
    String? rawAssetsDump,
    String? failureReason,
    DateTime? processedAt,
  }) async {
    final existing = await getOrCreatePending(targetDate, now: processedAt);
    jobs[targetDate] = ReviewGenerationJobEntity(
      id: existing.id,
      targetDate: existing.targetDate,
      status: ReviewGenerationJobStatus.failed,
      rawAssetsDump: rawAssetsDump,
      attemptCount: existing.attemptCount,
      failureReason: failureReason,
      processedAt: processedAt,
      createdAt: existing.createdAt,
    );
  }
}

ReviewGenerationJobEntity _job(
  String targetDate,
  ReviewGenerationJobStatus status, {
  int attemptCount = 0,
  String? failureReason,
  DateTime? processedAt,
}) {
  return ReviewGenerationJobEntity(
    id: 1,
    targetDate: targetDate,
    status: status,
    attemptCount: attemptCount,
    failureReason: failureReason,
    processedAt: processedAt,
    createdAt: DateTime(2026, 6, 21),
  );
}
