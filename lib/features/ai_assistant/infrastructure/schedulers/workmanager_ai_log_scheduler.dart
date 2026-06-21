import 'dart:io';

import 'package:workmanager/workmanager.dart';

import '../../domain/services/ai_log_scheduler.dart';
import 'noop_ai_log_scheduler.dart';

const String aiNightlyReviewTaskName = 'ai_nightly_review_generation';

AILogScheduler createAILogScheduler() {
  if (!Platform.isAndroid) {
    return const NoopAILogScheduler();
  }
  return WorkManagerAILogScheduler();
}

@pragma('vm:entry-point')
void aiLogWorkmanagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == aiNightlyReviewTaskName) {
      return true;
    }
    return true;
  });
}

class WorkManagerAILogScheduler implements AILogScheduler {
  final WorkManagerClient _client;
  final DateTime Function() _now;
  var _initialized = false;

  WorkManagerAILogScheduler({
    WorkManagerClient? client,
    DateTime Function()? now,
  }) : _client = client ?? const PluginWorkManagerClient(),
       _now = now ?? DateTime.now;

  @override
  Future<void> scheduleNightlyReviewGeneration({
    AILogScheduleConfig config = const AILogScheduleConfig(),
  }) async {
    await _ensureInitialized();
    await _client.registerPeriodicTask(
      uniqueName: config.uniqueName,
      taskName: config.taskName,
      frequency: config.frequency,
      flexInterval: config.flexInterval,
      initialDelay: config.initialDelay(_now()),
      constraints: _constraintsFor(config),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      tag: config.uniqueName,
    );
  }

  @override
  Future<void> cancelNightlyReviewGeneration({
    AILogScheduleConfig config = const AILogScheduleConfig(),
  }) async {
    await _client.cancelByUniqueName(config.uniqueName);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _client.initialize(aiLogWorkmanagerCallbackDispatcher);
    _initialized = true;
  }

  Constraints _constraintsFor(AILogScheduleConfig config) {
    return Constraints(
      networkType: config.requiresUnmeteredNetwork
          ? NetworkType.unmetered
          : NetworkType.notRequired,
      requiresCharging: config.requiresCharging,
    );
  }
}

abstract class WorkManagerClient {
  Future<void> initialize(Function callbackDispatcher);

  Future<void> registerPeriodicTask({
    required String uniqueName,
    required String taskName,
    Duration? frequency,
    Duration? flexInterval,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    String? tag,
  });

  Future<void> cancelByUniqueName(String uniqueName);
}

class PluginWorkManagerClient implements WorkManagerClient {
  const PluginWorkManagerClient();

  @override
  Future<void> initialize(Function callbackDispatcher) {
    return Workmanager().initialize(callbackDispatcher);
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
  }) {
    return Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: frequency,
      flexInterval: flexInterval,
      initialDelay: initialDelay,
      constraints: constraints,
      existingWorkPolicy: existingWorkPolicy,
      tag: tag,
    );
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) {
    return Workmanager().cancelByUniqueName(uniqueName);
  }
}
