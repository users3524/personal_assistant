import 'package:drift/drift.dart';

const String createReviewGenerationJobsTargetDateIndex =
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_review_generation_jobs_target_date '
    'ON review_generation_jobs(target_date)';
const String createReviewGenerationJobsStatusTargetDateIndex =
    'CREATE INDEX IF NOT EXISTS idx_review_generation_jobs_status_target_date '
    'ON review_generation_jobs(status, target_date)';

const reviewGenerationJobIndexStatements = [
  createReviewGenerationJobsTargetDateIndex,
  createReviewGenerationJobsStatusTargetDateIndex,
];

@TableIndex.sql(createReviewGenerationJobsTargetDateIndex)
@TableIndex.sql(createReviewGenerationJobsStatusTargetDateIndex)
class ReviewGenerationJobs extends Table {
  @override
  String get tableName => 'review_generation_jobs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetDate => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get rawAssetsDump => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get failureReason => text().nullable()();
  DateTimeColumn get processedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
