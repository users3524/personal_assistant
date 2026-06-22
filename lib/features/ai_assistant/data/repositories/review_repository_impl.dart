/// AI 复盘仓库实现。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/raw_context_pack_builder.dart';
import '../../../../core/ai/raw_context_pack_clipper.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/services/ai_log_scheduler.dart';
import '../../infrastructure/schedulers/ai_log_scheduler_factory.dart';
import '../datasources/chat_turn_dao.dart';
import '../datasources/milestone_dao.dart';
import '../datasources/review_generation_job_dao.dart';
import '../datasources/review_dao.dart';
import '../datasources/vector_embedding_dao.dart';
import '../../domain/services/review_generation_job_executor.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewDao _dao;

  ReviewRepositoryImpl(this._dao);

  @override
  Future<DailyReviewEntity> createDaily(DailyReviewEntity review) =>
      _dao.insertDaily(review);

  @override
  Future<DailyReviewEntity?> getDailyByDate(DateTime date) =>
      _dao.getDailyByDate(date);

  @override
  Future<List<DailyReviewEntity>> getAllDaily() => _dao.getAllDaily();

  @override
  Future<List<DailyReviewEntity>> getDailyByMonth(int year, int month) =>
      _dao.getDailyByMonth(year, month);

  @override
  Future<List<DailyReviewEntity>> getDailyByWeek(int year, int weekNumber) =>
      _dao.getDailyByWeek(year, weekNumber);

  @override
  Future<DailyReviewEntity> updateDaily(DailyReviewEntity review) =>
      _dao.updateDaily(review);

  @override
  Future<void> deleteDaily(DateTime date) => _dao.deleteDaily(date);

  @override
  Future<WeeklyReportEntity> createWeekly(WeeklyReportEntity report) =>
      _dao.insertWeekly(report);

  @override
  Future<WeeklyReportEntity?> getWeekly(int year, int weekNumber) =>
      _dao.getWeekly(year, weekNumber);

  @override
  Future<List<WeeklyReportEntity>> getWeeklyByYear(int year) =>
      _dao.getWeeklyByYear(year);

  @override
  Future<WeeklyReportEntity> updateWeekly(WeeklyReportEntity report) =>
      _dao.updateWeekly(report);

  @override
  Future<double> averageMoodInRange(DateTime start, DateTime end) =>
      _dao.averageMoodInRange(start, end);

  @override
  Future<double> averageEnergyInRange(DateTime start, DateTime end) =>
      _dao.averageEnergyInRange(start, end);

  @override
  Future<int> countDailyInRange(DateTime start, DateTime end) =>
      _dao.countDailyInRange(start, end);
}

// ===== Providers =====

final reviewDaoProvider = FutureProvider<ReviewDao>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ReviewDao(db);
});

final chatTurnDaoProvider = FutureProvider<ChatTurnDao>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ChatTurnDao(db);
});

final reviewGenerationJobDaoProvider = FutureProvider<ReviewGenerationJobDao>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ReviewGenerationJobDao(db);
});

final reviewGenerationJobExecutorProvider =
    FutureProvider<ReviewGenerationJobExecutor>((ref) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final jobs = ReviewGenerationJobDao(db);
      return ReviewGenerationJobExecutor(
        jobs: jobs,
        buildRawAssetsDump: (targetDate) async {
          final date = ReviewGenerationJobExecutor.parseTargetDate(targetDate);
          final clipped = await RawContextPackClipper(
            packBuilder: RawContextPackBuilder(db),
          ).build(date);
          return clipped.toJsonString();
        },
      );
    });

final milestoneDaoProvider = FutureProvider<MilestoneDao>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return MilestoneDao(db);
});

final vectorEmbeddingDaoProvider = FutureProvider<VectorEmbeddingDao>((
  ref,
) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return VectorEmbeddingDao(db);
});

final aiLogSchedulerProvider = Provider<AILogScheduler>((ref) {
  return createAILogScheduler();
});

final reviewRepositoryProvider = FutureProvider<ReviewRepository>((ref) async {
  final dao = await ref.watch(reviewDaoProvider.future);
  return ReviewRepositoryImpl(dao);
});
