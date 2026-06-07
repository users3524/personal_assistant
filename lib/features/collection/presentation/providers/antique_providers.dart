/// 文玩模块状态管理 Provider。
library;

export '../../data/repositories/antique_repository_impl.dart'
    show antiqueRepositoryProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/antique_repository_impl.dart';
import '../../domain/entities/antique_entity.dart';
import '../../domain/repositories/antique_repository.dart';

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
