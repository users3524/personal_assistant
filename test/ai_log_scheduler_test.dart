import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/ai_log_scheduler.dart';
import 'package:personal_assistant/features/ai_assistant/infrastructure/schedulers/noop_ai_log_scheduler.dart';
import 'package:personal_assistant/features/ai_assistant/infrastructure/schedulers/workmanager_ai_log_scheduler.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  group('AILogScheduleConfig', () {
    test('calculates the next 2:00 catch-up window locally', () {
      const config = AILogScheduleConfig();

      expect(
        config.initialDelay(DateTime(2026, 6, 21, 1, 30)),
        const Duration(minutes: 30),
      );
      expect(config.initialDelay(DateTime(2026, 6, 21, 3)), Duration.zero);
      expect(
        config.initialDelay(DateTime(2026, 6, 21, 5)),
        const Duration(hours: 21),
      );
    });
  });

  group('WorkManagerAILogScheduler', () {
    test(
      'registers Android work with charging and unmetered constraints',
      () async {
        final client = _FakeWorkManagerClient();
        final scheduler = WorkManagerAILogScheduler(
          client: client,
          now: () => DateTime(2026, 6, 21, 1),
        );

        await scheduler.scheduleNightlyReviewGeneration();

        expect(client.initializeCount, 1);
        expect(client.requests, hasLength(1));
        final request = client.requests.single;
        expect(request.uniqueName, 'ai_nightly_review_generation');
        expect(request.taskName, aiNightlyReviewTaskName);
        expect(request.frequency, const Duration(days: 1));
        expect(request.flexInterval, const Duration(hours: 3));
        expect(request.initialDelay, const Duration(hours: 1));
        expect(request.existingWorkPolicy, ExistingPeriodicWorkPolicy.update);
        expect(request.constraints?.networkType, NetworkType.unmetered);
        expect(request.constraints?.requiresCharging, true);
        expect(request.constraints?.requiresDeviceIdle, null);
      },
    );

    test('does not initialize WorkManager more than once', () async {
      final client = _FakeWorkManagerClient();
      final scheduler = WorkManagerAILogScheduler(client: client);

      await scheduler.scheduleNightlyReviewGeneration();
      await scheduler.scheduleNightlyReviewGeneration();

      expect(client.initializeCount, 1);
      expect(client.requests, hasLength(2));
    });

    test('cancels the unique nightly work name', () async {
      final client = _FakeWorkManagerClient();
      final scheduler = WorkManagerAILogScheduler(client: client);

      await scheduler.cancelNightlyReviewGeneration();

      expect(client.cancelledUniqueNames, ['ai_nightly_review_generation']);
    });
  });

  group('NoopAILogScheduler', () {
    test('schedule and cancel complete without platform work', () async {
      const scheduler = NoopAILogScheduler();

      await scheduler.scheduleNightlyReviewGeneration();
      await scheduler.cancelNightlyReviewGeneration();
    });
  });
}

class _FakeWorkManagerClient implements WorkManagerClient {
  int initializeCount = 0;
  final requests = <_PeriodicRequest>[];
  final cancelledUniqueNames = <String>[];

  @override
  Future<void> initialize(Function callbackDispatcher) async {
    initializeCount++;
  }

  @override
  Future<void> registerPeriodicTask({
    required String uniqueName,
    required String taskName,
    Duration? frequency,
    Duration? flexInterval,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    String? tag,
  }) async {
    requests.add(
      _PeriodicRequest(
        uniqueName: uniqueName,
        taskName: taskName,
        frequency: frequency,
        flexInterval: flexInterval,
        initialDelay: initialDelay,
        constraints: constraints,
        existingWorkPolicy: existingWorkPolicy,
        tag: tag,
      ),
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    cancelledUniqueNames.add(uniqueName);
  }
}

class _PeriodicRequest {
  final String uniqueName;
  final String taskName;
  final Duration? frequency;
  final Duration? flexInterval;
  final Duration? initialDelay;
  final Constraints? constraints;
  final ExistingPeriodicWorkPolicy? existingWorkPolicy;
  final String? tag;

  const _PeriodicRequest({
    required this.uniqueName,
    required this.taskName,
    this.frequency,
    this.flexInterval,
    this.initialDelay,
    this.constraints,
    this.existingWorkPolicy,
    this.tag,
  });
}
