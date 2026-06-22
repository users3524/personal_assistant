import '../entities/review_generation_job_entity.dart';
import '../repositories/review_generation_job_store.dart';

enum ReviewGenerationJobExecutionStatus {
  prepared,
  succeeded,
  skippedAlreadySucceeded,
  skippedExhausted,
  failed,
}

class ReviewGenerationJobExecutionResult {
  const ReviewGenerationJobExecutionResult({
    required this.targetDate,
    required this.status,
    this.job,
    this.failureReason,
  });

  final String targetDate;
  final ReviewGenerationJobExecutionStatus status;
  final ReviewGenerationJobEntity? job;
  final String? failureReason;

  bool get didPrepare =>
      status == ReviewGenerationJobExecutionStatus.prepared ||
      status == ReviewGenerationJobExecutionStatus.succeeded;
}

typedef ReviewRawAssetsDumpBuilder = Future<String> Function(String targetDate);
typedef ReviewPreparedJobRunner =
    Future<bool> Function(String targetDate, String rawAssetsDump);

class ReviewGenerationJobExecutor {
  ReviewGenerationJobExecutor({
    required ReviewGenerationJobStore jobs,
    required ReviewRawAssetsDumpBuilder buildRawAssetsDump,
    ReviewPreparedJobRunner? runPreparedJob,
    DateTime Function()? now,
  }) : _jobs = jobs,
       _buildRawAssetsDump = buildRawAssetsDump,
       _runPreparedJob = runPreparedJob,
       _now = now ?? DateTime.now;

  static final Map<String, Future<ReviewGenerationJobExecutionResult>>
  _inFlightByTargetDate = {};

  final ReviewGenerationJobStore _jobs;
  final ReviewRawAssetsDumpBuilder _buildRawAssetsDump;
  final ReviewPreparedJobRunner? _runPreparedJob;
  final DateTime Function() _now;

  Future<ReviewGenerationJobExecutionResult> executePending(String targetDate) {
    final normalized = normalizeTargetDate(targetDate);
    final inFlight = _inFlightByTargetDate[normalized];
    if (inFlight != null) return inFlight;

    late final Future<ReviewGenerationJobExecutionResult> future;
    future = _execute(normalized).whenComplete(() {
      if (identical(_inFlightByTargetDate[normalized], future)) {
        _inFlightByTargetDate.remove(normalized);
      }
    });
    _inFlightByTargetDate[normalized] = future;
    return future;
  }

  Future<ReviewGenerationJobExecutionResult> _execute(String targetDate) async {
    var job = await _jobs.getOrCreatePending(targetDate, now: _now());
    if (job.status == ReviewGenerationJobStatus.success) {
      return ReviewGenerationJobExecutionResult(
        targetDate: targetDate,
        status: ReviewGenerationJobExecutionStatus.skippedAlreadySucceeded,
        job: job,
      );
    }
    if (job.hasExhaustedStructuredCalls) {
      return ReviewGenerationJobExecutionResult(
        targetDate: targetDate,
        status: ReviewGenerationJobExecutionStatus.skippedExhausted,
        job: job,
      );
    }

    if (job.status == ReviewGenerationJobStatus.failed) {
      await _jobs.markPending(targetDate, now: _now());
      job = await _jobs.getByTargetDate(targetDate) ?? job;
    }

    try {
      final rawAssetsDump = await _buildRawAssetsDump(targetDate);
      await _jobs.saveRawAssetsDump(
        targetDate,
        rawAssetsDump: rawAssetsDump,
        now: _now(),
      );

      final runPreparedJob = _runPreparedJob;
      if (runPreparedJob != null) {
        final succeeded = await runPreparedJob(targetDate, rawAssetsDump);
        final updated = await _jobs.getByTargetDate(targetDate);
        return ReviewGenerationJobExecutionResult(
          targetDate: targetDate,
          status: succeeded
              ? ReviewGenerationJobExecutionStatus.succeeded
              : ReviewGenerationJobExecutionStatus.failed,
          job: updated ?? job,
          failureReason: updated?.failureReason,
        );
      }

      final updated = await _jobs.getByTargetDate(targetDate);
      return ReviewGenerationJobExecutionResult(
        targetDate: targetDate,
        status: ReviewGenerationJobExecutionStatus.prepared,
        job: updated ?? job,
      );
    } catch (error) {
      final failureReason = 'raw assets preparation failed: $error';
      await _jobs.markFailed(
        targetDate,
        failureReason: failureReason,
        processedAt: _now(),
      );
      final updated = await _jobs.getByTargetDate(targetDate);
      return ReviewGenerationJobExecutionResult(
        targetDate: targetDate,
        status: ReviewGenerationJobExecutionStatus.failed,
        job: updated ?? job,
        failureReason: failureReason,
      );
    }
  }

  static String normalizeTargetDate(String targetDate) {
    return formatTargetDate(parseTargetDate(targetDate));
  }

  static DateTime parseTargetDate(String targetDate) {
    final parts = targetDate.split('-');
    if (parts.length != 3) {
      throw FormatException('targetDate must be YYYY-MM-DD', targetDate);
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final parsed = DateTime(year, month, day);
    if (formatTargetDate(parsed) != targetDate) {
      throw FormatException(
        'targetDate must be a valid local date',
        targetDate,
      );
    }
    return parsed;
  }

  static String formatTargetDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
