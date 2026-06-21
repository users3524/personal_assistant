import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/review_generation_job_entity.dart';
import '../../domain/repositories/review_generation_job_store.dart';

class ReviewGenerationJobDao implements ReviewGenerationJobStore {
  final AppDatabase _db;

  ReviewGenerationJobDao(this._db);

  ReviewGenerationJobEntity _toEntity(ReviewGenerationJob row) =>
      ReviewGenerationJobEntity(
        id: row.id,
        targetDate: row.targetDate,
        status: ReviewGenerationJobStatus.fromStorage(row.status),
        rawAssetsDump: row.rawAssetsDump,
        attemptCount: row.attemptCount,
        failureReason: row.failureReason,
        processedAt: row.processedAt,
        createdAt: row.createdAt,
      );

  ReviewGenerationJobsCompanion _toCompanion(ReviewGenerationJobEntity entity) {
    return ReviewGenerationJobsCompanion(
      targetDate: Value(entity.targetDate),
      status: Value(entity.status.storageValue),
      rawAssetsDump: Value(entity.rawAssetsDump),
      attemptCount: Value(entity.attemptCount),
      failureReason: Value(entity.failureReason),
      processedAt: Value(entity.processedAt),
      createdAt: Value(entity.createdAt),
    );
  }

  Future<ReviewGenerationJobEntity> insert(
    ReviewGenerationJobEntity entity,
  ) async {
    final id = await _db
        .into(_db.reviewGenerationJobs)
        .insert(_toCompanion(entity));
    return entity.copyWith(id: id);
  }

  @override
  Future<ReviewGenerationJobEntity?> getByTargetDate(String targetDate) async {
    final row = await (_db.select(
      _db.reviewGenerationJobs,
    )..where((t) => t.targetDate.equals(targetDate))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<ReviewGenerationJobEntity> getOrCreatePending(
    String targetDate, {
    DateTime? now,
  }) async {
    final existing = await getByTargetDate(targetDate);
    if (existing != null) {
      return existing;
    }

    return insert(
      ReviewGenerationJobEntity(
        targetDate: targetDate,
        createdAt: now ?? DateTime.now(),
      ),
    );
  }

  Future<bool> needsCatchUp(String targetDate) async {
    final job = await getByTargetDate(targetDate);
    if (job == null) return true;
    if (job.status == ReviewGenerationJobStatus.success) return false;
    if (job.hasExhaustedStructuredCalls) return false;
    return job.status == ReviewGenerationJobStatus.pending ||
        job.status == ReviewGenerationJobStatus.failed;
  }

  @override
  Future<void> markPending(String targetDate, {DateTime? now}) async {
    final existing = await getByTargetDate(targetDate);
    if (existing == null) {
      await getOrCreatePending(targetDate, now: now);
      return;
    }

    await (_db.update(
      _db.reviewGenerationJobs,
    )..where((t) => t.targetDate.equals(targetDate))).write(
      const ReviewGenerationJobsCompanion(
        status: Value<String>('pending'),
        processedAt: Value<DateTime?>(null),
        failureReason: Value<String?>(null),
      ),
    );
  }

  @override
  Future<int> incrementAttempt(String targetDate, {DateTime? now}) async {
    await getOrCreatePending(targetDate, now: now);
    await _db.customStatement(
      '''
UPDATE review_generation_jobs
SET attempt_count = attempt_count + 1
WHERE target_date = ?
''',
      [targetDate],
    );
    final job = await getByTargetDate(targetDate);
    return job?.attemptCount ?? 0;
  }

  @override
  Future<void> markSuccess(
    String targetDate, {
    String? rawAssetsDump,
    DateTime? processedAt,
  }) async {
    await _markProcessed(
      targetDate,
      status: ReviewGenerationJobStatus.success,
      rawAssetsDump: rawAssetsDump,
      processedAt: processedAt,
    );
  }

  @override
  Future<void> markFailed(
    String targetDate, {
    String? rawAssetsDump,
    String? failureReason,
    DateTime? processedAt,
  }) async {
    await _markProcessed(
      targetDate,
      status: ReviewGenerationJobStatus.failed,
      rawAssetsDump: rawAssetsDump,
      failureReason: failureReason,
      processedAt: processedAt,
    );
  }

  Future<int> pruneSuccessfulRawAssetDumps({
    DateTime? now,
    Duration retention = const Duration(days: 7),
  }) async {
    final cutoff = (now ?? DateTime.now()).subtract(retention);
    return (_db.update(_db.reviewGenerationJobs)..where(
          (t) =>
              t.status.equals(ReviewGenerationJobStatus.success.storageValue) &
              t.rawAssetsDump.isNotNull() &
              t.processedAt.isSmallerOrEqualValue(cutoff),
        ))
        .write(const ReviewGenerationJobsCompanion(rawAssetsDump: Value(null)));
  }

  Future<void> _markProcessed(
    String targetDate, {
    required ReviewGenerationJobStatus status,
    String? rawAssetsDump,
    String? failureReason,
    DateTime? processedAt,
  }) async {
    await getOrCreatePending(targetDate, now: processedAt);
    await _db.customStatement(
      '''
UPDATE review_generation_jobs
SET status = ?,
    raw_assets_dump = ?,
    failure_reason = ?,
    processed_at = ?
WHERE target_date = ?
''',
      [
        status.storageValue,
        rawAssetsDump,
        failureReason,
        _toSqliteSeconds(processedAt ?? DateTime.now()),
        targetDate,
      ],
    );
  }

  int _toSqliteSeconds(DateTime dateTime) {
    return (dateTime.millisecondsSinceEpoch / 1000).round();
  }
}
