import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/review_generation_job_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/repositories/review_generation_job_store.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/review_generation_job_executor.dart';

void main() {
  group('ReviewGenerationJobExecutor', () {
    test('prepares pending job and stores raw assets dump', () async {
      final store = _FakeReviewGenerationJobStore();
      final executor = ReviewGenerationJobExecutor(
        jobs: store,
        now: () => DateTime(2026, 6, 21, 8),
        buildRawAssetsDump: (targetDate) async {
          expect(targetDate, '2026-06-20');
          return '{"target_date":"2026-06-20","clip":{"kept_count":1}}';
        },
      );

      final result = await executor.executePending('2026-06-20');
      final job = store.jobs['2026-06-20'];

      expect(result.status, ReviewGenerationJobExecutionStatus.prepared);
      expect(result.didPrepare, true);
      expect(job?.status, ReviewGenerationJobStatus.pending);
      expect(
        job?.rawAssetsDump,
        '{"target_date":"2026-06-20","clip":{"kept_count":1}}',
      );
      expect(job?.failureReason, null);
      expect(job?.processedAt, null);
    });

    test(
      'deduplicates concurrent execution for the same target date',
      () async {
        final store = _FakeReviewGenerationJobStore();
        final completer = Completer<String>();
        var calls = 0;
        final executor = ReviewGenerationJobExecutor(
          jobs: store,
          buildRawAssetsDump: (_) {
            calls++;
            return completer.future;
          },
        );

        final first = executor.executePending('2026-06-20');
        final second = executor.executePending('2026-06-20');
        completer.complete('{"target_date":"2026-06-20"}');
        final results = await Future.wait([first, second]);

        expect(second, same(first));
        expect(calls, 1);
        expect(
          results.map((result) => result.status),
          everyElement(ReviewGenerationJobExecutionStatus.prepared),
        );
        expect(store.jobs['2026-06-20']?.rawAssetsDump, isNotNull);
      },
    );

    test('skips already successful and exhausted jobs', () async {
      final store = _FakeReviewGenerationJobStore();
      store.jobs['2026-06-19'] = _job(
        '2026-06-19',
        ReviewGenerationJobStatus.success,
      );
      store.jobs['2026-06-20'] = _job(
        '2026-06-20',
        ReviewGenerationJobStatus.failed,
        attemptCount: 3,
      );
      var calls = 0;
      final executor = ReviewGenerationJobExecutor(
        jobs: store,
        buildRawAssetsDump: (_) async {
          calls++;
          return '{}';
        },
      );

      final success = await executor.executePending('2026-06-19');
      final exhausted = await executor.executePending('2026-06-20');

      expect(
        success.status,
        ReviewGenerationJobExecutionStatus.skippedAlreadySucceeded,
      );
      expect(
        exhausted.status,
        ReviewGenerationJobExecutionStatus.skippedExhausted,
      );
      expect(calls, 0);
    });

    test('marks job failed when raw assets preparation throws', () async {
      final store = _FakeReviewGenerationJobStore();
      final executor = ReviewGenerationJobExecutor(
        jobs: store,
        now: () => DateTime(2026, 6, 21, 8),
        buildRawAssetsDump: (_) async => throw StateError('db unavailable'),
      );

      final result = await executor.executePending('2026-06-20');
      final job = store.jobs['2026-06-20'];

      expect(result.status, ReviewGenerationJobExecutionStatus.failed);
      expect(job?.status, ReviewGenerationJobStatus.failed);
      expect(job?.failureReason, contains('db unavailable'));
      expect(job?.processedAt, DateTime(2026, 6, 21, 8));
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
      () => _job(targetDate, ReviewGenerationJobStatus.pending, now: now),
    );
  }

  @override
  Future<void> markPending(String targetDate, {DateTime? now}) async {
    final existing = await getOrCreatePending(targetDate, now: now);
    jobs[targetDate] = _job(
      existing.targetDate,
      ReviewGenerationJobStatus.pending,
      id: existing.id,
      attemptCount: existing.attemptCount,
      rawAssetsDump: existing.rawAssetsDump,
      now: existing.createdAt,
    );
  }

  @override
  Future<int> incrementAttempt(String targetDate, {DateTime? now}) async {
    final existing = await getOrCreatePending(targetDate, now: now);
    final next = _job(
      existing.targetDate,
      existing.status,
      id: existing.id,
      attemptCount: existing.attemptCount + 1,
      rawAssetsDump: existing.rawAssetsDump,
      failureReason: existing.failureReason,
      processedAt: existing.processedAt,
      now: existing.createdAt,
    );
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
    jobs[targetDate] = _job(
      existing.targetDate,
      ReviewGenerationJobStatus.pending,
      id: existing.id,
      attemptCount: existing.attemptCount,
      rawAssetsDump: rawAssetsDump,
      now: existing.createdAt,
    );
  }

  @override
  Future<void> markSuccess(
    String targetDate, {
    String? rawAssetsDump,
    DateTime? processedAt,
  }) async {
    final existing = await getOrCreatePending(targetDate, now: processedAt);
    jobs[targetDate] = _job(
      existing.targetDate,
      ReviewGenerationJobStatus.success,
      id: existing.id,
      attemptCount: existing.attemptCount,
      rawAssetsDump: rawAssetsDump,
      processedAt: processedAt,
      now: existing.createdAt,
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
    jobs[targetDate] = _job(
      existing.targetDate,
      ReviewGenerationJobStatus.failed,
      id: existing.id,
      attemptCount: existing.attemptCount,
      rawAssetsDump: rawAssetsDump,
      failureReason: failureReason,
      processedAt: processedAt,
      now: existing.createdAt,
    );
  }
}

ReviewGenerationJobEntity _job(
  String targetDate,
  ReviewGenerationJobStatus status, {
  int? id,
  int attemptCount = 0,
  String? rawAssetsDump,
  String? failureReason,
  DateTime? processedAt,
  DateTime? now,
}) {
  return ReviewGenerationJobEntity(
    id: id ?? 1,
    targetDate: targetDate,
    status: status,
    rawAssetsDump: rawAssetsDump,
    attemptCount: attemptCount,
    failureReason: failureReason,
    processedAt: processedAt,
    createdAt: now ?? DateTime(2026, 6, 21, 8),
  );
}
