/// AI 复盘模块 DAO — drift 数据库操作。
library;

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/services/iso_week.dart';

class ReviewDao {
  final AppDatabase _db;

  ReviewDao(this._db);

  // ===== 日报转换 =====

  DailyReviewEntity _dailyToEntity(DailyReview row) {
    return DailyReviewEntity(
      id: row.id,
      date: row.date,
      summary: row.summary,
      highlights: row.highlights,
      improvements: row.improvements,
      energyLevel: row.energyLevel,
      moodLevel: row.moodLevel,
      completedTodoIds: row.completedTodoIds
          .map((s) => int.tryParse(s) ?? 0)
          .toList(),
      pattingMinutes: row.pattingMinutes,
      aiComment: row.aiComment,
      aiSuggestion: row.aiSuggestion,
      isAiGenerated: row.isAiGenerated,
      isManuallyEdited: row.isManuallyEdited,
      calibrationRequired: row.calibrationRequired,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DailyReviewsCompanion _dailyToCompanion(DailyReviewEntity entity) {
    return DailyReviewsCompanion(
      date: Value(entity.date),
      summary: Value(entity.summary),
      highlights: Value(entity.highlights),
      improvements: Value(entity.improvements),
      energyLevel: Value(entity.energyLevel),
      moodLevel: Value(entity.moodLevel),
      completedTodoIds: Value<List<String>>(
        entity.completedTodoIds.map((e) => e.toString()).toList(),
      ),
      pattingMinutes: Value(entity.pattingMinutes),
      aiComment: Value(entity.aiComment),
      aiSuggestion: Value(entity.aiSuggestion),
      isAiGenerated: Value(entity.isAiGenerated),
      isManuallyEdited: Value(entity.isManuallyEdited),
      calibrationRequired: Value(entity.calibrationRequired),
    );
  }

  // ===== 周报转换 =====

  WeeklyReportEntity _weeklyToEntity(WeeklyReport row) {
    return WeeklyReportEntity(
      id: row.id,
      weekNumber: row.weekNumber,
      year: row.year,
      overview: row.overview,
      highlights: row.highlights,
      improvements: row.improvements,
      nextWeekPlan: row.nextWeekPlan,
      isAiGenerated: row.isAiGenerated,
      isManuallyEdited: row.isManuallyEdited,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  WeeklyReportsCompanion _weeklyToCompanion(WeeklyReportEntity entity) {
    return WeeklyReportsCompanion(
      weekNumber: Value(entity.weekNumber),
      year: Value(entity.year),
      overview: Value(entity.overview),
      highlights: Value(entity.highlights),
      improvements: Value(entity.improvements),
      nextWeekPlan: Value(entity.nextWeekPlan),
      isAiGenerated: Value(entity.isAiGenerated),
      isManuallyEdited: Value(entity.isManuallyEdited),
    );
  }

  // ===== 日报 CRUD =====

  Future<DailyReviewEntity> insertDaily(DailyReviewEntity entity) async {
    final id = await _db
        .into(_db.dailyReviews)
        .insert(_dailyToCompanion(entity), mode: InsertMode.insertOrReplace);
    return entity.copyWith(id: id);
  }

  Future<DailyReviewEntity?> getDailyByDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final row =
        await (_db.select(_db.dailyReviews)
              ..where((t) => _dateInHalfOpenRange(t.date, dayStart, dayEnd)))
            .getSingleOrNull();
    return row != null ? _dailyToEntity(row) : null;
  }

  Future<List<DailyReviewEntity>> getAllDaily() async {
    final rows = await (_db.select(
      _db.dailyReviews,
    )..orderBy([(t) => OrderingTerm.desc(t.date)])).get();
    return rows.map(_dailyToEntity).toList();
  }

  Future<List<DailyReviewEntity>> getDailyByMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final rows =
        await (_db.select(_db.dailyReviews)
              ..where((t) => _dateInHalfOpenRange(t.date, start, end))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_dailyToEntity).toList();
  }

  Future<List<DailyReviewEntity>> getDailyByWeek(
    int year,
    int weekNumber,
  ) async {
    final start = IsoWeek.startDateOf(year, weekNumber);
    final end = start.add(const Duration(days: 7));
    final rows =
        await (_db.select(_db.dailyReviews)
              ..where((t) => _dateInHalfOpenRange(t.date, start, end))
              ..orderBy([(t) => OrderingTerm.asc(t.date)]))
            .get();
    return rows.map(_dailyToEntity).toList();
  }

  Future<DailyReviewEntity> updateDaily(DailyReviewEntity entity) async {
    await (_db.update(
      _db.dailyReviews,
    )..where((t) => t.id.equals(entity.id!))).write(
      _dailyToCompanion(entity).copyWith(updatedAt: Value(DateTime.now())),
    );
    return entity;
  }

  Future<void> deleteDaily(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    await (_db.delete(
      _db.dailyReviews,
    )..where((t) => t.date.equals(normalized))).go();
  }

  // ===== 周报 CRUD =====

  Future<WeeklyReportEntity> insertWeekly(WeeklyReportEntity entity) async {
    final id = await _db
        .into(_db.weeklyReports)
        .insert(_weeklyToCompanion(entity), mode: InsertMode.insertOrReplace);
    return entity.copyWith(id: id);
  }

  Future<WeeklyReportEntity?> getWeekly(int year, int weekNumber) async {
    final rows =
        await (_db.select(_db.weeklyReports)..where(
              (t) => t.year.equals(year) & t.weekNumber.equals(weekNumber),
            ))
            .get();
    return rows.isNotEmpty ? _weeklyToEntity(rows.first) : null;
  }

  Future<List<WeeklyReportEntity>> getWeeklyByYear(int year) async {
    final rows =
        await (_db.select(_db.weeklyReports)
              ..where((t) => t.year.equals(year))
              ..orderBy([(t) => OrderingTerm.desc(t.weekNumber)]))
            .get();
    return rows.map(_weeklyToEntity).toList();
  }

  Future<WeeklyReportEntity> updateWeekly(WeeklyReportEntity entity) async {
    await (_db.update(
      _db.weeklyReports,
    )..where((t) => t.id.equals(entity.id!))).write(
      _weeklyToCompanion(entity).copyWith(updatedAt: Value(DateTime.now())),
    );
    return entity;
  }

  // ===== 统计 =====

  Future<double> averageMoodInRange(DateTime start, DateTime end) async {
    final rows = await (_db.select(
      _db.dailyReviews,
    )..where((t) => _dateInHalfOpenRange(t.date, start, end))).get();
    if (rows.isEmpty) return 0;
    return rows.fold<int>(0, (s, r) => s + r.moodLevel) / rows.length;
  }

  Future<double> averageEnergyInRange(DateTime start, DateTime end) async {
    final rows = await (_db.select(
      _db.dailyReviews,
    )..where((t) => _dateInHalfOpenRange(t.date, start, end))).get();
    if (rows.isEmpty) return 0;
    return rows.fold<int>(0, (s, r) => s + r.energyLevel) / rows.length;
  }

  Future<int> countDailyInRange(DateTime start, DateTime end) async {
    final rows = await (_db.select(
      _db.dailyReviews,
    )..where((t) => _dateInHalfOpenRange(t.date, start, end))).get();
    return rows.length;
  }

  // ===== 辅助 =====

  Expression<bool> _dateInHalfOpenRange(
    DateTimeColumn column,
    DateTime start,
    DateTime end,
  ) {
    return column.isBiggerOrEqualValue(start) & column.isSmallerThanValue(end);
  }
}
