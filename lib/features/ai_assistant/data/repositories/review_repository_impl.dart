/// AI 复盘仓库实现。
library;

import 'package:riverpod/riverpod.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/review_dao.dart';

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
  Future<List<DailyReviewEntity>> getDailyByMonth(int year, int month) =>
      _dao.getDailyByMonth(year, month);

  @override
  Future<List<DailyReviewEntity>> getDailyByWeek(int year, int weekNumber) =>
      _dao.getDailyByWeek(year, weekNumber);

  @override
  Future<DailyReviewEntity> updateDaily(DailyReviewEntity review) =>
      _dao.updateDaily(review);

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

final reviewRepositoryProvider = FutureProvider<ReviewRepository>((ref) async {
  final dao = await ref.watch(reviewDaoProvider.future);
  return ReviewRepositoryImpl(dao);
});
