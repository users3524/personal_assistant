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
import 'dart:math';

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

/// 网格显示分类筛选（空=全部）
final categoryDisplayFilterProvider = StateProvider<String>((ref) => '');

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
  final notifier = DailyPickConfigNotifier();
  // 异步从持久化加载配置
  Future.microtask(() => notifier.loadFromStorage());
  return notifier;
});

class DailyPickConfigNotifier extends StateNotifier<DailyPickConfig> {
  DailyPickConfigNotifier() : super(const DailyPickConfig());
  bool _loaded = false;

  Future<void> loadFromStorage() async {
    if (_loaded) return;
    _loaded = true;
    final counts = await AppSettingsPersistence().getDailyPickCounts();
    if (counts.isNotEmpty) {
      state = DailyPickConfig(counts: counts);
    }
  }

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
    AppSettingsPersistence().setDailyPickCounts(newCounts);
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

/// 刷新计数器 — 用于换一换功能
final dailyPickRefreshCounter = StateProvider<int>((ref) => 0);

final dailyPickProvider = FutureProvider<List<AntiqueEntity>>((ref) {
  ref.watch(dailyPickRefreshCounter); // 监听刷新
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final items = await repo.getAll();
    final config = ref.watch(dailyPickConfigProvider);
    final now = DateTime.now();
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    // 统计最近一个月（从今天往前推 30 天）每件藏品的打卡次数
    final freq = <int, int>{};
    for (final item in items) {
      if (item.id == null) continue;
      final logs = await repo.getPattingLogs(item.id!);
      final recentLogs = logs.where((l) => l.date.isAfter(monthAgo)).length;
      freq[item.id!] = recentLogs;
    }

    // 按打卡频率升序排列（最少的排前面）
    items.sort((a, b) {
      final fa = freq[a.id] ?? 0;
      final fb = freq[b.id] ?? 0;
      return fa.compareTo(fb); // 升序：最少优先
    });

    // 按配置取每个类别指定数量（从最低频的 2 倍 N 中随机选取）
    final picks = <AntiqueEntity>[];
    final rand = Random(DateTime.now().millisecondsSinceEpoch ~/ 60000);
    for (final entry in config.counts.entries) {
      final pool = items.where((i) => i.category == entry.key).toList();
      // 取最低频的 2×count 个作为候选池，从中随机选
      final takeCount = entry.value;
      final poolSize = (takeCount * 2).clamp(1, pool.length);
      final candidatePool = pool.take(poolSize).toList();
      candidatePool.shuffle(rand);
      picks.addAll(candidatePool.take(takeCount));
    }
    return picks;
  });
});

/// 盘串网格列数（默认 2 列）
final gridColumnsProvider = StateProvider<int>((ref) => 2);
