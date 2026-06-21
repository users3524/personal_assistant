import '../entities/review_generation_job_entity.dart';

abstract class ReviewGenerationJobStore {
  Future<ReviewGenerationJobEntity?> getByTargetDate(String targetDate);

  Future<ReviewGenerationJobEntity> getOrCreatePending(
    String targetDate, {
    DateTime? now,
  });

  Future<void> markPending(String targetDate, {DateTime? now});

  Future<int> incrementAttempt(String targetDate, {DateTime? now});

  Future<void> markSuccess(
    String targetDate, {
    String? rawAssetsDump,
    DateTime? processedAt,
  });

  Future<void> markFailed(
    String targetDate, {
    String? rawAssetsDump,
    String? failureReason,
    DateTime? processedAt,
  });
}
