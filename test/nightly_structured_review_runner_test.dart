import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/review_generation_job_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/repositories/review_generation_job_store.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/nightly_structured_review_runner.dart';

void main() {
  group('NightlyStructuredReviewRunner', () {
    test('succeeds with the initial JSON call', () async {
      final store = _FakeReviewGenerationJobStore();
      final calls = <NightlyReviewModelRequest>[];
      final runner = _runner(
        store: store,
        calls: calls,
        responses: [
          '{"comment":"今天推进很稳。","suggestion":"明天先做最重要的一件事。","sentiment_tag":"高效"}',
        ],
      );

      final result = await runner.run(
        targetDate: '2026-06-20',
        rawAssetsDump: '{"todos":[]}',
      );

      expect(result.isSuccess, true);
      expect(result.callsMade, 1);
      expect(result.lastStage, NightlyReviewCallStage.initialJson);
      expect(result.output?.sentimentTag, '高效');
      expect(calls.map((call) => call.stage), [
        NightlyReviewCallStage.initialJson,
      ]);
      expect(store.jobs['2026-06-20']?.attemptCount, 1);
      expect(
        store.jobs['2026-06-20']?.status,
        ReviewGenerationJobStatus.success,
      );
    });

    test('uses one JSON repair call after malformed JSON', () async {
      final store = _FakeReviewGenerationJobStore();
      final calls = <NightlyReviewModelRequest>[];
      final runner = _runner(
        store: store,
        calls: calls,
        responses: [
          '这不是 JSON',
          '{"comment":"今天有起伏但完成了主线。","suggestion":"明天把任务拆小。","sentiment_tag":"平稳"}',
        ],
      );

      final result = await runner.run(
        targetDate: '2026-06-20',
        rawAssetsDump: '{"todos":[{"title":"写报告"}]}',
      );

      expect(result.isSuccess, true);
      expect(result.callsMade, 2);
      expect(calls.map((call) => call.stage), [
        NightlyReviewCallStage.initialJson,
        NightlyReviewCallStage.repairJson,
      ]);
      expect(calls.last.previousOutput, '这不是 JSON');
      expect(store.jobs['2026-06-20']?.attemptCount, 2);
      expect(
        store.jobs['2026-06-20']?.status,
        ReviewGenerationJobStatus.success,
      );
    });

    test('falls back to plain text as the third and final call', () async {
      final store = _FakeReviewGenerationJobStore();
      final calls = <NightlyReviewModelRequest>[];
      final runner = _runner(
        store: store,
        calls: calls,
        responses: [
          '这不是 JSON',
          '{"comment":"缺字段"}',
          '''
1. 评语：今天虽然有些波动，但你仍然保住了关键节奏。
2. 改进建议：明天先完成一个小目标，再处理零散事务。
3. 情绪标签：平稳
''',
        ],
      );

      final result = await runner.run(
        targetDate: '2026-06-20',
        rawAssetsDump: '{"chat_turns":[]}',
      );

      expect(result.isSuccess, true);
      expect(result.callsMade, 3);
      expect(result.lastStage, NightlyReviewCallStage.plainTextFallback);
      expect(result.output?.comment, contains('关键节奏'));
      expect(calls.map((call) => call.stage), [
        NightlyReviewCallStage.initialJson,
        NightlyReviewCallStage.repairJson,
        NightlyReviewCallStage.plainTextFallback,
      ]);
      expect(store.jobs['2026-06-20']?.attemptCount, 3);
      expect(
        store.jobs['2026-06-20']?.status,
        ReviewGenerationJobStatus.success,
      );
    });

    test('marks calibration required after three failed calls', () async {
      final store = _FakeReviewGenerationJobStore();
      final calls = <NightlyReviewModelRequest>[];
      final calibrations = <_CalibrationMark>[];
      final runner = _runner(
        store: store,
        calls: calls,
        calibrations: calibrations,
        responses: ['这不是 JSON', '{"comment":"缺字段"}', '', '不应该调用第四次'],
      );

      final result = await runner.run(
        targetDate: '2026-06-20',
        rawAssetsDump: '{"daily_review_draft":null}',
      );

      expect(result.isSuccess, false);
      expect(result.callsMade, 3);
      expect(result.calibrationRequired, true);
      expect(calls, hasLength(3));
      expect(store.jobs['2026-06-20']?.attemptCount, 3);
      expect(
        store.jobs['2026-06-20']?.status,
        ReviewGenerationJobStatus.failed,
      );
      expect(store.jobs['2026-06-20']?.failureReason, contains('纯文本降级'));
      expect(calibrations.single.date, DateTime(2026, 6, 20));
      expect(calibrations.single.calibrationRequired, true);
    });

    test(
      'does not call the model again after attempts are exhausted',
      () async {
        final store = _FakeReviewGenerationJobStore();
        store.jobs['2026-06-20'] = _job(
          '2026-06-20',
          ReviewGenerationJobStatus.failed,
          attemptCount: 3,
        );
        final calls = <NightlyReviewModelRequest>[];
        final calibrations = <_CalibrationMark>[];
        final runner = _runner(
          store: store,
          calls: calls,
          calibrations: calibrations,
          responses: ['不应该调用'],
        );

        final result = await runner.run(
          targetDate: '2026-06-20',
          rawAssetsDump: '{"todos":[]}',
        );

        expect(result.isSuccess, false);
        expect(result.callsMade, 0);
        expect(calls, isEmpty);
        expect(store.jobs['2026-06-20']?.attemptCount, 3);
        expect(
          store.jobs['2026-06-20']?.status,
          ReviewGenerationJobStatus.failed,
        );
        expect(calibrations.single.date, DateTime(2026, 6, 20));
      },
    );
  });
}

NightlyStructuredReviewRunner _runner({
  required _FakeReviewGenerationJobStore store,
  required List<NightlyReviewModelRequest> calls,
  required List<String> responses,
  List<_CalibrationMark>? calibrations,
}) {
  var index = 0;
  return NightlyStructuredReviewRunner(
    jobs: store,
    now: () => DateTime(2026, 6, 21, 2, index),
    callModel: (request) async {
      calls.add(request);
      return responses[index++];
    },
    markCalibrationRequired: (date, {required calibrationRequired, now}) async {
      calibrations?.add(
        _CalibrationMark(
          date: date,
          calibrationRequired: calibrationRequired,
          now: now,
        ),
      );
    },
  );
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
    createdAt: now ?? DateTime(2026, 6, 21, 2),
  );
}

class _CalibrationMark {
  final DateTime date;
  final bool calibrationRequired;
  final DateTime? now;

  const _CalibrationMark({
    required this.date,
    required this.calibrationRequired,
    this.now,
  });
}
