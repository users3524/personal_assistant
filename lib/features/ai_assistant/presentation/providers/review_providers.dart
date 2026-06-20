/// AI 复盘模块状态管理 Provider。
library;

export '../../data/repositories/review_repository_impl.dart'
    show reviewRepositoryProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/services/iso_week.dart';

// ===== 当前日期 =====

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ===== 日报 Provider =====

final dailyReviewProvider = FutureProvider.family<DailyReviewEntity?, DateTime>(
  (ref, date) {
    return ref.watch(reviewRepositoryProvider.future).then((repo) {
      return repo.getDailyByDate(date);
    });
  },
);

/// 可刷新的日报列表（按月）
final dailyListByMonthProvider =
    FutureProvider.family<List<DailyReviewEntity>, int>((ref, month) {
      final now = DateTime.now();
      return ref.watch(reviewRepositoryProvider.future).then((repo) {
        return repo.getDailyByMonth(now.year, month);
      });
    });

/// 可刷新的日报列表（按年月，year*100+month 作为 key）
final dailyListByYearMonthProvider =
    FutureProvider.family<List<DailyReviewEntity>, int>((ref, key) {
      final year = key ~/ 100;
      final month = key % 100;
      return ref.watch(reviewRepositoryProvider.future).then((repo) {
        return repo.getDailyByMonth(year, month);
      });
    });

// ===== 周报 Provider =====

final weeklyReportProvider = FutureProvider.family<WeeklyReportEntity?, int>((
  ref,
  weekNumber,
) {
  final now = IsoWeek.fromDate(DateTime.now());
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.getWeekly(now.year, weekNumber);
  });
});

/// 可刷新周报（year*100+weekNumber 作为 key，year 使用 ISO 周年）
final weeklyReportByYearWeekProvider =
    FutureProvider.family<WeeklyReportEntity?, int>((ref, key) {
      final year = key ~/ 100;
      final weekNumber = key % 100;
      return ref.watch(reviewRepositoryProvider.future).then((repo) {
        return repo.getWeekly(year, weekNumber);
      });
    });

final weeklyListByYearProvider = FutureProvider<List<WeeklyReportEntity>>((
  ref,
) {
  final now = IsoWeek.fromDate(DateTime.now());
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.getWeeklyByYear(now.year);
  });
});

/// 全部日报记录（用于历史查看）
final allDailyReviewsProvider = FutureProvider<List<DailyReviewEntity>>((ref) {
  return ref.watch(reviewRepositoryProvider.future).then((repo) {
    return repo.getAllDaily();
  });
});

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
  return IsoWeek.fromDate(DateTime.now()).weekNumber;
});

/// 当前 ISO 周
final currentIsoWeekProvider = Provider<IsoWeek>((ref) {
  return IsoWeek.fromDate(DateTime.now());
});
