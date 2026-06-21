import '../entities/review_generation_job_entity.dart';
import '../repositories/review_generation_job_store.dart';

class ReviewCatchUpGuardResult {
  final String targetDate;
  final bool shouldRunCatchUp;
  final ReviewGenerationJobEntity job;

  const ReviewCatchUpGuardResult({
    required this.targetDate,
    required this.shouldRunCatchUp,
    required this.job,
  });
}

class ReviewCatchUpGuard {
  final ReviewGenerationJobStore _jobs;
  final DateTime Function() _now;

  ReviewCatchUpGuard(this._jobs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<ReviewCatchUpGuardResult> ensureYesterdayJob() async {
    final now = _now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final targetDate = formatLocalDate(yesterday);
    final existing = await _jobs.getByTargetDate(targetDate);
    final shouldRunCatchUp =
        existing == null ||
        existing.status == ReviewGenerationJobStatus.pending ||
        existing.status == ReviewGenerationJobStatus.failed;

    final job = shouldRunCatchUp
        ? await _jobs.getOrCreatePending(targetDate, now: now)
        : existing;

    if (existing?.status == ReviewGenerationJobStatus.failed) {
      await _jobs.markPending(targetDate, now: now);
      final pending = await _jobs.getByTargetDate(targetDate);
      return ReviewCatchUpGuardResult(
        targetDate: targetDate,
        shouldRunCatchUp: true,
        job: pending ?? job,
      );
    }

    return ReviewCatchUpGuardResult(
      targetDate: targetDate,
      shouldRunCatchUp: shouldRunCatchUp,
      job: job,
    );
  }

  static String formatLocalDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
