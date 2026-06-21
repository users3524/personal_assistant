/// Collection module state providers.
library;

export '../../data/repositories/antique_repository_impl.dart'
    show antiqueRepositoryProvider;

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_settings_persistence.dart';
import '../../data/repositories/antique_repository_impl.dart';
import '../../domain/entities/antique_entity.dart';
import '../../domain/repositories/antique_repository.dart';

final antiqueSortModeProvider = StateProvider<String>((ref) => '');

enum CollectionViewMode { grid, calendar }

final collectionViewModeProvider = StateProvider<CollectionViewMode>(
  (ref) => CollectionViewMode.grid,
);

final calendarMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final calendarFilterProvider = StateProvider<String?>((ref) => null);

final categoryDisplayFilterProvider = StateProvider<String>((ref) => '');

final antiqueListProvider =
    AsyncNotifierProvider<AntiqueListNotifier, List<AntiqueEntity>>(
      AntiqueListNotifier.new,
    );

class AntiqueListNotifier extends AsyncNotifier<List<AntiqueEntity>> {
  @override
  Future<List<AntiqueEntity>> build() async {
    final repo = await ref.watch(antiqueRepositoryProvider.future);
    final items = await repo.getAll();
    final sortMode = ref.watch(antiqueSortModeProvider);
    if (sortMode.isNotEmpty) {
      return _applySort(items, sortMode, repo);
    }
    return items;
  }

  Future<void> refresh() async {
    final repo = await ref.watch(antiqueRepositoryProvider.future);
    final items = await repo.getAll();
    final sortMode = ref.watch(antiqueSortModeProvider);
    if (sortMode.isNotEmpty) {
      state = AsyncValue.data(await _applySort(items, sortMode, repo));
    } else {
      state = AsyncValue.data(items);
    }
    ref.invalidate(categoryCountProvider);
    ref.invalidate(pattingCalendarProvider);
    ref.invalidate(pattingFrequencyProvider);
    ref.invalidate(monthlyPattingFrequencyProvider);
    ref.invalidate(totalPattingDurationProvider);
    ref.invalidate(coldPalaceRankProvider);
    ref.invalidate(nightOwlRankProvider);
    ref.invalidate(costPerPlayProvider);
    ref.invalidate(recentVarietyProvider);
    ref.invalidate(dailyPickProvider);
  }

  Future<List<AntiqueEntity>> _applySort(
    List<AntiqueEntity> items,
    String mode,
    AntiqueRepository repo,
  ) async {
    switch (mode) {
      case 'acquired_asc':
        items.sort((a, b) => a.acquiredDate.compareTo(b.acquiredDate));
        break;
      case 'acquired_desc':
        items.sort((a, b) => b.acquiredDate.compareTo(a.acquiredDate));
        break;
      case 'price_asc':
        items.sort(
          (a, b) => (a.acquiredPrice ?? 0).compareTo(b.acquiredPrice ?? 0),
        );
        break;
      case 'price_desc':
        items.sort(
          (a, b) => (b.acquiredPrice ?? 0).compareTo(a.acquiredPrice ?? 0),
        );
        break;
      case 'patting':
        final latestByItem = await repo.latestPattingDateByItem();
        items.sort((a, b) => _compareByLatestPatting(a, b, latestByItem));
        break;
    }
    return items;
  }

  Future<AntiqueRepository> _getRepo() async =>
      ref.read(antiqueRepositoryProvider.future);

  Future<void> sortBySortMode(String mode) async {
    final repo = await _getRepo();
    final sorted = await repo.getAll();
    switch (mode) {
      case 'acquired_asc':
        sorted.sort((a, b) => a.acquiredDate.compareTo(b.acquiredDate));
        break;
      case 'acquired_desc':
        sorted.sort((a, b) => b.acquiredDate.compareTo(a.acquiredDate));
        break;
      case 'price_asc':
        sorted.sort(
          (a, b) => (a.acquiredPrice ?? 0).compareTo(b.acquiredPrice ?? 0),
        );
        break;
      case 'price_desc':
        sorted.sort(
          (a, b) => (b.acquiredPrice ?? 0).compareTo(a.acquiredPrice ?? 0),
        );
        break;
      case 'patting':
        final latestByItem = await repo.latestPattingDateByItem();
        sorted.sort((a, b) => _compareByLatestPatting(a, b, latestByItem));
        break;
      default:
        state = AsyncValue.data(sorted);
        return;
    }
    state = AsyncValue.data(sorted);
  }

  int _compareByLatestPatting(
    AntiqueEntity a,
    AntiqueEntity b,
    Map<int, DateTime> latestByItem,
  ) {
    final logA = latestByItem[a.id];
    final logB = latestByItem[b.id];
    if (logA == null && logB == null) return 0;
    if (logA == null) return 1;
    if (logB == null) return -1;
    return logB.compareTo(logA);
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

final categoryCountProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.countByCategory();
  });
});

final latestPattingPhotosProvider = FutureProvider<Map<int, String>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.getLatestPattingPhotos();
  });
});

final pattingCalendarProvider =
    FutureProvider.family<Map<int, List<PattingLogEntity>>, DateTime>((
      ref,
      month,
    ) {
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

final pattingFrequencyProvider = FutureProvider<Map<int, int>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.countPattingLogsByItem();
  });
});

final monthlyPattingFrequencyProvider = FutureProvider<Map<int, int>>((ref) {
  final now = DateTime.now();
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    return repo.countPattingLogsByItemInRange(monthStart, monthEnd);
  });
});

final totalPattingDurationProvider = FutureProvider<Map<int, int>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.sumPattingMinutesByItem();
  });
});

final todayPattingDurationProvider = FutureProvider<int>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.sumPattingMinutesByDate(DateTime.now());
  });
});

final coldPalaceRankProvider = FutureProvider<Map<int, int>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final items = await repo.getAll();
    final latestByItem = await repo.latestPattingDateByItem();
    final daysMap = <int, int>{};
    final now = DateTime.now();
    for (final item in items) {
      final itemId = item.id;
      if (itemId == null) continue;
      final latestDate = latestByItem[itemId];
      daysMap[itemId] = now.difference(latestDate ?? item.acquiredDate).inDays;
    }
    return daysMap;
  });
});

final nightOwlRankProvider = FutureProvider<Map<int, int>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.countNightPattingLogsByItem();
  });
});

final costPerPlayProvider = FutureProvider<Map<int, double>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final items = await repo.getAll();
    final pattingCounts = await repo.countPattingLogsByItem();
    final costMap = <int, double>{};
    for (final item in items) {
      final itemId = item.id;
      if (itemId == null ||
          item.acquiredPrice == null ||
          item.acquiredPrice! <= 0) {
        continue;
      }
      final playCount = pattingCounts[itemId] ?? 0;
      if (playCount == 0) continue;
      costMap[itemId] = item.acquiredPrice! / playCount;
    }
    return costMap;
  });
});

final recentVarietyProvider = FutureProvider<Map<int, int>>((ref) {
  final now = DateTime.now();
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  return ref.watch(antiqueRepositoryProvider.future).then((repo) {
    return repo.countPattingLogsByItemInRange(twoWeeksAgo, now);
  });
});

class DailyPickConfig {
  final Map<String, int> counts;

  const DailyPickConfig({
    this.counts = const {'\u6838\u6843': 2, '\u624b\u4e32': 4},
  });

  DailyPickConfig copyWith({Map<String, int>? counts}) =>
      DailyPickConfig(counts: counts ?? this.counts);
}

final dailyPickConfigProvider =
    StateNotifierProvider<DailyPickConfigNotifier, DailyPickConfig>((ref) {
      final notifier = DailyPickConfigNotifier();
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

final dailyPickProvider = FutureProvider<List<AntiqueEntity>>((ref) {
  return ref.watch(antiqueRepositoryProvider.future).then((repo) async {
    final items = await repo.getAll();
    final config = ref.watch(dailyPickConfigProvider);
    final now = DateTime.now();
    final monthAgo = DateTime(now.year, now.month - 1, now.day);
    final freq = await repo.countPattingLogsByItemInRange(monthAgo, now);

    items.sort((a, b) {
      final fa = freq[a.id] ?? 0;
      final fb = freq[b.id] ?? 0;
      return fa.compareTo(fb);
    });

    final picks = <AntiqueEntity>[];
    final rand = Random(DateTime.now().microsecondsSinceEpoch);
    for (final entry in config.counts.entries) {
      final pool = items.where((i) => i.category == entry.key).toList();
      final takeCount = entry.value;
      final poolSize = (takeCount * 2).clamp(1, pool.length);
      final candidatePool = pool.take(poolSize).toList();
      candidatePool.shuffle(rand);
      picks.addAll(candidatePool.take(takeCount));
    }
    return picks;
  });
});

final gridColumnsProvider = StateProvider<int>((ref) => 2);
