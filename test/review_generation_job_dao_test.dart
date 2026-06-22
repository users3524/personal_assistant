import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/review_generation_job_dao.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/review_generation_job_entity.dart';

void main() {
  group('ReviewGenerationJobDao', () {
    late AppDatabase db;
    late ReviewGenerationJobDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = ReviewGenerationJobDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('creates a pending job for a local target date once', () async {
      final createdAt = DateTime(2026, 6, 21, 9);

      final first = await dao.getOrCreatePending('2026-06-20', now: createdAt);
      final second = await dao.getOrCreatePending(
        '2026-06-20',
        now: createdAt.add(const Duration(hours: 1)),
      );

      expect(first.id, isNotNull);
      expect(second.id, first.id);
      expect(second.targetDate, '2026-06-20');
      expect(second.status, ReviewGenerationJobStatus.pending);
      expect(second.createdAt, createdAt);
      expect(await db.select(db.reviewGenerationJobs).get(), hasLength(1));
    });

    test('needs catch-up for missing, pending and failed jobs only', () async {
      expect(await dao.needsCatchUp('2026-06-20'), true);

      await dao.getOrCreatePending('2026-06-20');
      expect(await dao.needsCatchUp('2026-06-20'), true);

      expect(await dao.incrementAttempt('2026-06-20'), 1);
      await dao.markFailed(
        '2026-06-20',
        failureReason: 'json parse failed',
        processedAt: DateTime(2026, 6, 21, 2),
      );
      expect(await dao.needsCatchUp('2026-06-20'), true);

      await dao.markSuccess(
        '2026-06-20',
        rawAssetsDump: '{"target_date":"2026-06-20"}',
        processedAt: DateTime(2026, 6, 21, 3),
      );
      expect(await dao.needsCatchUp('2026-06-20'), false);

      final job = await dao.getByTargetDate('2026-06-20');
      expect(job?.status, ReviewGenerationJobStatus.success);
      expect(job?.rawAssetsDump, '{"target_date":"2026-06-20"}');
      expect(job?.attemptCount, 1);
      expect(job?.processedAt, DateTime(2026, 6, 21, 3));
    });

    test('does not need catch-up after three structured calls fail', () async {
      await dao.getOrCreatePending('2026-06-20');
      await dao.incrementAttempt('2026-06-20');
      await dao.incrementAttempt('2026-06-20');
      await dao.incrementAttempt('2026-06-20');
      await dao.markFailed(
        '2026-06-20',
        failureReason: 'structured output exhausted',
        processedAt: DateTime(2026, 6, 21, 2),
      );

      expect(await dao.needsCatchUp('2026-06-20'), false);
      final job = await dao.getByTargetDate('2026-06-20');
      expect(job?.attemptCount, 3);
      expect(job?.status, ReviewGenerationJobStatus.failed);
    });

    test('mark pending clears failure details but keeps attempts', () async {
      await dao.incrementAttempt('2026-06-20');
      await dao.markFailed(
        '2026-06-20',
        rawAssetsDump: '{"bad":true}',
        failureReason: 'bad shape',
        processedAt: DateTime(2026, 6, 21, 2),
      );

      await dao.markPending('2026-06-20');

      final job = await dao.getByTargetDate('2026-06-20');
      expect(job?.status, ReviewGenerationJobStatus.pending);
      expect(job?.attemptCount, 1);
      expect(job?.failureReason, null);
      expect(job?.processedAt, null);
    });

    test('saves raw assets dump while keeping job pending', () async {
      await dao.markFailed(
        '2026-06-20',
        rawAssetsDump: '{"old":true}',
        failureReason: 'network',
        processedAt: DateTime(2026, 6, 21, 2),
      );

      await dao.saveRawAssetsDump(
        '2026-06-20',
        rawAssetsDump: '{"clip":{"kept_count":1}}',
        now: DateTime(2026, 6, 21, 8),
      );

      final job = await dao.getByTargetDate('2026-06-20');
      expect(job?.status, ReviewGenerationJobStatus.pending);
      expect(job?.rawAssetsDump, '{"clip":{"kept_count":1}}');
      expect(job?.failureReason, null);
      expect(job?.processedAt, null);
    });

    test('prunes only expired successful raw asset dumps', () async {
      await dao.markSuccess(
        '2026-06-10',
        rawAssetsDump: '{"old":true}',
        processedAt: DateTime(2026, 6, 10, 2),
      );
      await dao.markSuccess(
        '2026-06-15',
        rawAssetsDump: '{"fresh":true}',
        processedAt: DateTime(2026, 6, 15, 2),
      );
      await dao.markFailed(
        '2026-06-09',
        rawAssetsDump: '{"failed":true}',
        failureReason: 'network',
        processedAt: DateTime(2026, 6, 9, 2),
      );
      await dao.getOrCreatePending('2026-06-08');
      await db.customStatement(
        'UPDATE review_generation_jobs '
        'SET raw_assets_dump = ? WHERE target_date = ?',
        ['{"pending":true}', '2026-06-08'],
      );

      final pruned = await dao.pruneSuccessfulRawAssetDumps(
        now: DateTime(2026, 6, 18, 2),
      );

      expect(pruned, 1);
      expect((await dao.getByTargetDate('2026-06-10'))?.rawAssetsDump, null);
      expect(
        (await dao.getByTargetDate('2026-06-15'))?.rawAssetsDump,
        '{"fresh":true}',
      );
      expect(
        (await dao.getByTargetDate('2026-06-09'))?.rawAssetsDump,
        '{"failed":true}',
      );
      expect(
        (await dao.getByTargetDate('2026-06-08'))?.rawAssetsDump,
        '{"pending":true}',
      );
    });
  });
}
