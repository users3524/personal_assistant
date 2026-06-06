/// 待办模块状态管理 Provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 仓库 Provider 由 todo_repository_impl.dart 提供（FutureProvider）
export '../../data/repositories/todo_repository_impl.dart'
    show todoRepositoryProvider;

import '../../data/repositories/todo_repository_impl.dart';
import '../../domain/entities/todo_entity.dart';
import '../../domain/repositories/todo_repository.dart';

// ===== 分类切换状态 =====

/// 当前选中的分类
final selectedCategoryProvider = StateProvider<TodoCategory>((ref) {
  return TodoCategory.life;
});

// ===== 待办列表 Provider（自动刷新） =====

/// 可刷新待办列表
final todoListProvider =
    AsyncNotifierProvider<TodoListNotifier, List<TodoEntity>>(
  TodoListNotifier.new,
);

class TodoListNotifier extends AsyncNotifier<List<TodoEntity>> {
  @override
  Future<List<TodoEntity>> build() async {
    final repo = await ref.watch(todoRepositoryProvider.future);
    return repo.getAll();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  Future<TodoRepository> _getRepo() async {
    return ref.read(todoRepositoryProvider.future);
  }

  Future<void> addTodo(TodoEntity todo) async {
    final repo = await _getRepo();
    await repo.create(todo);
    await refresh();
  }

  Future<void> updateTodo(TodoEntity todo) async {
    final repo = await _getRepo();
    await repo.update(todo);
    await refresh();
  }

  Future<void> deleteTodo(int id) async {
    final repo = await _getRepo();
    await repo.delete(id);
    await refresh();
  }

  Future<void> completeTodo(int id) async {
    final repo = await _getRepo();
    await repo.complete(id);
    await refresh();
  }

  Future<void> cancelTodo(int id) async {
    final repo = await _getRepo();
    await repo.cancel(id);
    await refresh();
  }

  Future<void> toggleStar(int id) async {
    final repo = await _getRepo();
    await repo.toggleStar(id);
    await refresh();
  }

  Future<void> startTodo(int id) async {
    final repo = await _getRepo();
    await repo.start(id);
    await refresh();
  }
}

// ===== 分类待办列表 =====

final todosByCategoryProvider =
    FutureProvider.family<List<TodoEntity>, TodoCategory>((ref, category) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getByCategory(category);
  });
});

// ===== 搜索 =====

final searchTodosProvider =
    FutureProvider.family<List<TodoEntity>, String>((ref, keyword) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.search(keyword);
  });
});

// ===== 统计 Provider =====

final todayCompletedCountProvider = FutureProvider<int>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.countTodayCompleted();
  });
});

final todayTotalCountProvider = FutureProvider<int>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.countTodayTotal();
  });
});

final weeklyCompletionRateProvider = FutureProvider<double>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.weeklyCompletionRate();
  });
});

final delayRateProvider = FutureProvider<double>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.delayRate();
  });
});

/// 今日完成率（0-100）
final todayCompletionRateProvider = Provider<double>((ref) {
  final completed = ref.watch(todayCompletedCountProvider).valueOrNull ?? 0;
  final total = ref.watch(todayTotalCountProvider).valueOrNull ?? 1;
  if (total == 0) return 0;
  return (completed / total) * 100;
});
