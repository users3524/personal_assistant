/// AI 复盘模块仓库接口。
library;

import '../entities/review_entity.dart';

abstract class ReviewRepository {
  // ===== 日报 =====
  Future<DailyReviewEntity> createDaily(DailyReviewEntity review);
  Future<DailyReviewEntity?> getDailyByDate(DateTime date);
  Future<List<DailyReviewEntity>> getAllDaily();
  Future<List<DailyReviewEntity>> getDailyByMonth(int year, int month);
  Future<List<DailyReviewEntity>> getDailyByWeek(int year, int weekNumber);
  Future<DailyReviewEntity> updateDaily(DailyReviewEntity review);

  // ===== 周报 =====
  Future<WeeklyReportEntity> createWeekly(WeeklyReportEntity report);
  Future<WeeklyReportEntity?> getWeekly(int year, int weekNumber);
  Future<List<WeeklyReportEntity>> getWeeklyByYear(int year);
  Future<WeeklyReportEntity> updateWeekly(WeeklyReportEntity report);

  // ===== 统计 =====
  Future<double> averageMoodInRange(DateTime start, DateTime end);
  Future<double> averageEnergyInRange(DateTime start, DateTime end);
  Future<int> countDailyInRange(DateTime start, DateTime end);
}
