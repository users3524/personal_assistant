/// 文玩模块状态管理 Provider。
library;

export '../../data/repositories/antique_repository_impl.dart'
    show antiqueRepositoryProvider;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/antique_repository_impl.dart';
import '../../domain/entities/antique_entity.dart';
import '../../domain/repositories/antique_repository.dart';
import '../../../../core/database/app_settings_persistence.dart';

// 排序模式
final antiqueSortModeProvider = StateProvider<String>((ref) => '');

// 视图模式：grid / calendar
enum CollectionViewMode { grid, calendar }

final collectionViewModeProvider =
    StateProvider<CollectionViewMode>((ref) => CollectionViewMode.grid);

// 月历当前查看的月份
final calendarMonthProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

// 月历分类筛选
final calendarFilterProvider = StateProvider<String?>((ref) => null);

// ===== 列表 Provider（可刷新） =====

final antiqueListProvider =
    AsyncNotifierProvider<AntiqueListNotifier, List<AntiqueEntity>>(
  AntiqueListNotifier.new,
);

class AntiqueListNotifier extends AsyncNotifier<List<AntiqueEntity>> {
  @override
  Future<List<AntiqueEntity>> build() async {
    final repo = await ref.watch(antiqueRepositoryProvider.future);
    return repo.getAll();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    ref.invalidate(categoryCountProvider);
    ref.invalidate(totalValuationProvider);
    ref.invalidate(pattingCalendarProvider);
    ref.invalidate(dailyPickProvider);
    ref.invalidate(pattingFrequencyProvider);
    ref.invalidate(monthlyPattingFrequencyProvider);
  }

  Future<AntiqueRepository> _getRepo() async =>
      ref.read(antiqueRepositoryProvider.future);

  Future<void> sortBySortMode(String mode) async {
    final repo = await _getRepo();
    List<AntiqueEntity> sorted;
    switch (mode) {
      case 'acquired_asc':
        sorted = await repo.getAll();
        sorted.sort((a, b) => a.acquiredDate.compareTo(b.acquiredDate));
        break;
      case 'acquired_desc':
        sorted = await repo.getAll();
        sorted.sort((a, b) => b.acquiredDate.compareTo(a.acquiredDate));
        break;
      case 'price_asc':
        sorted = await repo.getAll();
        sorted.sort((a, b) => (a.acquiredPrice ?? 0).compareTo(b.acquiredPrice ?? 0));
        break;
      case 'price_desc':
        sorted = await repo.getAll();
        sorted.sort((a, b) => (b.acquiredPrice ?? 0).compareTo(a.acquiredPrice ?? 0));
        break;
      case 'patting':
        sorted = await repo.getAll();
        // 有盘玩记录的排前面，按最近盘玩时间
        final pattingMap = <int, DateTime>{};
        for (final item in sorted) {
          final logs = await repo.getPattingLogs(item.id!);
          if (logs.isNotEmpty) {
            pattingMap[item.id!] = logs.first.date;
          }
        }
        sorted.sort((a, b) {
          final logA = pattingMap[a.id];
          final logB = pattingMap[b.id];
          if (logA == null && logB == null) return 0;
          if (logA == null) return 1;
          if (logB == null) return -1;
          return logB.compareTo(logA);
        });
        break;
      default:
        state = AsyncValue.data(await repo.getAll());
        return;
    }
    state = AsyncValue.data(sorted);
  }

  Future<void> addItem(AntiqueEntity item) async {
    final repo = await _getRepo();
    await repo.create(item);
    await refresh();
  }

  Future<void> updateItem(AntiqueEntity item) async {
    final repo = await _getRepo();
    await repo.update(item);
    await refresh();
  }

  Future<void> deleteItem(int id) async {
    final repo = await _getRepo();
    await repo.delete(id);
    await refresh();
  }
}

// ===== 分类统计 =====

final categoryCountProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.countByCategory();
  });
});

final totalValuationProvider = FutureProvider<double>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.totalValuation();
  });
});

// ===== 最新打卡照片（列表页封面） =====

final latestPattingPhotosProvider = FutureProvider<Map<int, String>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.getLatestPattingPhotos();
  });
});

// ===== 月历打卡数据 =====

/// 按月份返回 Map<day, List<PattingLogEntity>>（仅含照片的日志）
final pattingCalendarProvider =
    FutureProvider.family<Map<int, List<PattingLogEntity>>, DateTime>((ref, month) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final logs = await repo.getPattingLogsByMonth(month.year, month.month);
    final result = <int, List<PattingLogEntity>>{};
    for (final log in logs) {
      if (log.photoPaths.isEmpty) continue;
      final day = log.date.day;
      result.putIfAbsent(day, () => []);
      result[day]!.add(log);
    }
    return result;
  });
});

/// 所有藏品的打卡频率计数（用于每日推荐）
final pattingFrequencyProvider = FutureProvider<Map<int, int>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final items = await repo.getAll();
    final freq = <int, int>{};
    for (final item in items) {
      if (item.id == null) continue;
      final logs = await repo.getPattingLogs(item.id!);
      freq[item.id!] = logs.length;
    }
    return freq;
  });
});

/// 当月打卡频率计数（用于侍寝榜）
final monthlyPattingFrequencyProvider = FutureProvider<Map<int, int>>((ref) {
  final now = DateTime.now();
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final items = await repo.getAll();
    final freq = <int, int>{};
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    for (final item in items) {
      if (item.id == null) continue;
      final logs = await repo.getPattingLogs(item.id!);
      // 只统计当月
      final monthLogs = logs.where((l) =>
          l.date.isAfter(monthStart) && l.date.isBefore(monthEnd)).length;
      if (monthLogs > 0) {
        freq[item.id!] = monthLogs;
      }
    }
    return freq;
  });
});

// ===== 每日翻牌推荐配置 =====

/// 翻牌推荐配置：每个类别推荐的数量
class DailyPickConfig {
  final Map<String, int> counts;

  const DailyPickConfig({this.counts = const {'核桃': 2, '手串': 4}});

  DailyPickConfig copyWith({Map<String, int>? counts}) =>
      DailyPickConfig(counts: counts ?? this.counts);
}

final dailyPickConfigProvider = StateNotifierProvider<DailyPickConfigNotifier, DailyPickConfig>((ref) {
  return DailyPickConfigNotifier();
});

class DailyPickConfigNotifier extends StateNotifier<DailyPickConfig> {
  final void Function(Map<String, int>)? _onChanged;

  DailyPickConfigNotifier({void Function(Map<String, int>)? onChanged})
      : _onChanged = onChanged,
        super(const DailyPickConfig());

  void load(Map<String, int> counts) {
    if (counts.isNotEmpty) {
      state = DailyPickConfig(counts: counts);
    }
  }

  void setCount(String category, int count) {
    if (count <= 0) return;
    final newCounts = Map<String, int>.from(state.counts);
    newCounts[category] = count;
    state = DailyPickConfig(counts: newCounts);
    _onChanged?.call(newCounts);
  }

  void addCategory(String category, int count) {
    final newCounts = Map<String, int>.from(state.counts);
    newCounts[category] = count;
    state = DailyPickConfig(counts: newCounts);
  }

  void removeCategory(String category) {
    final newCounts = Map<String, int>.from(state.counts);
    newCounts.remove(category);
    state = DailyPickConfig(counts: newCounts);
  }
}

// ===== 每日翻牌推荐（按配置） =====

final dailyPickProvider = FutureProvider<List<AntiqueEntity>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final items = await repo.getAll();
    final freq = await ref.watch(pattingFrequencyProvider.future);
    final config = ref.watch(dailyPickConfigProvider);

    // 按打卡频率排序
    items.sort((a, b) {
      final fa = freq[a.id] ?? 0;
      final fb = freq[b.id] ?? 0;
      return fb.compareTo(fa);
    });

    // 按配置取每个类别指定数量
    final picks = <AntiqueEntity>[];
    for (final entry in config.counts.entries) {
      final categoryItems = items.where((i) => i.category == entry.key).take(entry.value);
      picks.addAll(categoryItems);
    }
    return picks;
  });
});

/// 盘串网格列数（默认 2 列）
final gridColumnsProvider = StateProvider<int>((ref) => 2);
