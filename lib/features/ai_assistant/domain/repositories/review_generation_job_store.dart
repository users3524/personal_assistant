import '../entities/review_generation_job_entity.dart';

abstract class ReviewGenerationJobStore {
  Future<ReviewGenerationJobEntity?> getByTargetDate(String targetDate);

  Future<ReviewGenerationJobEntity> getOrCreatePending(
    String targetDate, {
    DateTime? now,
  });

  Future<void> markPending(String targetDate, {DateTime? now});
}
