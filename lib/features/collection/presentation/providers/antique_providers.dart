/// 文玩模块状态管理 Provider。
library;

export '../../data/repositories/antique_repository_impl.dart'
    show antiqueRepositoryProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/antique_repository_impl.dart';
import '../../domain/entities/antique_entity.dart';
import '../../domain/repositories/antique_repository.dart';

// 排序模式
final antiqueSortModeProvider = StateProvider<String>((ref) => '');

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
  }

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

  Future<AntiqueRepository> _getRepo() async =>
      ref.read(antiqueRepositoryProvider.future);

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
