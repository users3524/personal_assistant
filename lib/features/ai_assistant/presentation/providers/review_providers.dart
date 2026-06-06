/// AI 复盘模块状态管理 Provider。
library;

export '../../data/repositories/review_repository_impl.dart'
    show reviewRepositoryProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review_entity.dart';

// ===== 当前日期 =====

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ===== 日报 Provider =====

final dailyReviewProvider =
    FutureProvider.family<DailyReviewEntity?, DateTime>((ref, date) {
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.getDailyByDate(date);
  });
});

/// 可刷新的日报列表（按月）
final dailyListByMonthProvider =
    FutureProvider.family<List<DailyReviewEntity>, int>((ref, month) {
  final now = DateTime.now();
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.getDailyByMonth(now.year, month);
  });
});

// ===== 周报 Provider =====

final weeklyReportProvider =
    FutureProvider.family<WeeklyReportEntity?, int>((ref, weekNumber) {
  final now = DateTime.now();
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.getWeekly(now.year, weekNumber);
  });
});

final weeklyListByYearProvider = FutureProvider<List<WeeklyReportEntity>>((ref) {
  final now = DateTime.now();
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.getWeeklyByYear(now.year);
  });
});

// ===== 统计 Provider =====

final monthlyAvgMoodProvider = FutureProvider<double>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.averageMoodInRange(start, end);
  });
});

final monthlyAvgEnergyProvider = FutureProvider<double>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.averageEnergyInRange(start, end);
  });
});

/// 本周周数
final currentWeekNumberProvider = Provider<int>((ref) {
  final now = DateTime.now();
  final firstDay = DateTime(now.year, 1, 1);
  final diff = now.difference(firstDay).inDays;
  return ((diff + firstDay.weekday - 1) / 7).ceil();
});
