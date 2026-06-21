import '../../domain/services/ai_log_scheduler.dart';

AILogScheduler createAILogScheduler() => const NoopAILogScheduler();

class NoopAILogScheduler implements AILogScheduler {
  const NoopAILogScheduler();

  @override
  Future<void> scheduleNightlyReviewGeneration({
    AILogScheduleConfig config = const AILogScheduleConfig(),
  }) async {}

  @override
  Future<void> cancelNightlyReviewGeneration({
    AILogScheduleConfig config = const AILogScheduleConfig(),
  }) async {}
}
