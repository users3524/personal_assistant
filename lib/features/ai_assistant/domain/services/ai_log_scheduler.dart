class AILogScheduleConfig {
  final String uniqueName;
  final String taskName;
  final Duration frequency;
  final Duration? flexInterval;
  final int windowStartHour;
  final int windowEndHour;
  final bool requiresCharging;
  final bool requiresUnmeteredNetwork;

  const AILogScheduleConfig({
    this.uniqueName = 'ai_nightly_review_generation',
    this.taskName = 'ai_nightly_review_generation',
    this.frequency = const Duration(days: 1),
    this.flexInterval = const Duration(hours: 3),
    this.windowStartHour = 2,
    this.windowEndHour = 5,
    this.requiresCharging = true,
    this.requiresUnmeteredNetwork = true,
  });

  Duration initialDelay(DateTime now) {
    final normalized = DateTime(now.year, now.month, now.day);
    var nextWindowStart = normalized.add(Duration(hours: windowStartHour));
    final windowEnd = normalized.add(Duration(hours: windowEndHour));
    if (!now.isBefore(windowEnd)) {
      nextWindowStart = nextWindowStart.add(const Duration(days: 1));
    }
    if (now.isBefore(nextWindowStart)) {
      return nextWindowStart.difference(now);
    }
    return Duration.zero;
  }
}

abstract class AILogScheduler {
  Future<void> scheduleNightlyReviewGeneration({
    AILogScheduleConfig config = const AILogScheduleConfig(),
  });

  Future<void> cancelNightlyReviewGeneration({
    AILogScheduleConfig config = const AILogScheduleConfig(),
  });
}
