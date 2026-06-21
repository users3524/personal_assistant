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
      expect(job?.attemptCount, 2);
      expect(job?.processedAt, DateTime(2026, 6, 21, 3));
    });

    test('mark pending clears failure details but keeps attempts', () async {
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
  });
}
