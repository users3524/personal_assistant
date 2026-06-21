/// 待办模块状态管理 Provider。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// 仓库 Provider 由 todo_repository_impl.dart 提供（FutureProvider）
export '../../data/repositories/todo_repository_impl.dart'
    show todoRepositoryProvider;

import '../../data/repositories/todo_repository_impl.dart';
import '../../domain/entities/todo_entity.dart';
import '../../domain/repositories/todo_repository.dart';

// ===== 分类切换状态 =====

/// 当前选中的分类筛选（null = 全部）
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// 清单筛选中“未归清单”的哨兵值。
const int unlistedTodoListFilter = -1;

/// 当前选中的清单筛选（null = 全部，-1 = 未归清单）
final selectedTodoListFilterProvider = StateProvider<int?>((ref) => null);

/// 排序方式
final sortModeProvider = StateProvider<String>((ref) => 'createdAt');

// ===== 清单 Provider =====

final todoListsProvider =
    AsyncNotifierProvider<TodoListsNotifier, List<TodoListEntity>>(
      TodoListsNotifier.new,
    );

class TodoListsNotifier extends AsyncNotifier<List<TodoListEntity>> {
  @override
  Future<List<TodoListEntity>> build() async {
    final repo = await ref.watch(todoRepositoryProvider.future);
    return repo.getLists();
  }

  Future<TodoRepository> _getRepo() async {
    return ref.read(todoRepositoryProvider.future);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  Future<TodoListEntity> saveList(TodoListEntity list) async {
    final repo = await _getRepo();
    final saved = await repo.saveList(list);
    state = AsyncData(await repo.getLists());
    ref.invalidate(todoListProvider);
    return saved;
  }

  Future<void> deleteList(int id) async {
    final repo = await _getRepo();
    await repo.deleteList(id);
    state = AsyncData(await repo.getLists());
    if (ref.read(selectedTodoListFilterProvider) == id) {
      ref.read(selectedTodoListFilterProvider.notifier).state = null;
    }
    ref.invalidate(todoListProvider);
  }
}

// ===== 待办列表 Provider =====

/// 可刷新待办总列表
final todoListProvider =
    AsyncNotifierProvider<TodoListNotifier, List<TodoEntity>>(
      TodoListNotifier.new,
    );

class TodoListNotifier extends AsyncNotifier<List<TodoEntity>> {
  @override
  Future<List<TodoEntity>> build() async {
    final repo = await ref.watch(todoRepositoryProvider.future);
    return repo.getTree();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    ref.invalidate(todayCompletedCountProvider);
    ref.invalidate(todayTotalCountProvider);
    ref.invalidate(weeklyCompletionRateProvider);
    ref.invalidate(delayRateProvider);
  }

  Future<TodoRepository> _getRepo() async {
    return ref.read(todoRepositoryProvider.future);
  }

  Future<void> addTodo(TodoEntity todo) async {
    final repo = await _getRepo();
    await repo.create(todo);
    await refresh();
  }

  /// 添加子任务
  Future<void> addSubtask(int parentId, TodoEntity subtask) async {
    final repo = await _getRepo();
    await repo.addSubtask(parentId, subtask);
    await refresh();
  }

  Future<void> updateTodo(TodoEntity todo) async {
    final repo = await _getRepo();
    await repo.update(todo);
    await refresh();
  }

  /// 软删除（移入回收站）
  Future<void> deleteTodo(int id) async {
    final repo = await _getRepo();
    await repo.delete(id);
    await refresh();
  }

  /// 乐观删除：先更新本地状态再异步入库（用于 Dismissible 防闪退）
  void deleteTodoLocal(int id) {
    final currentList = state.valueOrNull ?? [];
    state = AsyncData(currentList.where((t) => t.id != id).toList());
    // 后台异步入库
    unawaited(_deleteAfter(id));
  }

  Future<void> _deleteAfter(int id) async {
    try {
      final repo = await _getRepo();
      await repo.delete(id);
    } catch (_) {}
  }

  /// 恢复软删除
  Future<void> restoreTodo(int id) async {
    final repo = await _getRepo();
    await repo.restore(id);
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

  Future<void> reopenTodo(int id) async {
    final repo = await _getRepo();
    await repo.reopen(id);
    await refresh();
  }
}

// ===== 分类待办列表 =====

final todosByCategoryProvider = FutureProvider.family<List<TodoEntity>, String>(
  (ref, category) {
    return ref.watch(todoRepositoryProvider.future).then((repo) {
      return repo.getByCategory(category);
    });
  },
);

// ===== 搜索 =====

final searchTodosProvider = FutureProvider.family<List<TodoEntity>, String>((
  ref,
  keyword,
) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.search(keyword);
  });
});

// ===== 分段列表 =====

/// 活跃待办（未完成、未逾期）
final activeTodosProvider = FutureProvider<List<TodoEntity>>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getActive();
  });
});

/// 逾期待办
final overdueTodosProvider = FutureProvider<List<TodoEntity>>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getOverdue();
  });
});

/// 今日待办（截止日期为今天）
final todayTodosProvider = FutureProvider<List<TodoEntity>>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getToday();
  });
});

/// 归档（已完成/已取消）
final archivedTodosProvider = FutureProvider<List<TodoEntity>>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getArchived();
  });
});

/// 回收站（已软删除）
final trashedTodosProvider = FutureProvider<List<TodoEntity>>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getTrashed();
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
