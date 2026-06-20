/// 待办仓库实现 — 桥接 DAO 与领域层。
library;

import 'package:riverpod/riverpod.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/todo_entity.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_dao.dart';

class TodoRepositoryImpl implements TodoRepository {
  final TodoDao _dao;

  TodoRepositoryImpl(this._dao);

  // ===== 清单 =====
  @override
  Future<List<TodoListEntity>> getLists() => _dao.getLists();
  @override
  Future<TodoListEntity> saveList(TodoListEntity list) => _dao.saveList(list);
  @override
  Future<void> deleteList(int id) => _dao.deleteList(id);

  // ===== CRUD =====
  @override
  Future<TodoEntity> create(TodoEntity todo) => _dao.insert(todo);
  @override
  Future<TodoEntity?> getById(int id) => _dao.getById(id);
  @override
  Future<List<TodoEntity>> getAll() => _dao.getTree();
  @override
  Future<List<TodoEntity>> getTree() => _dao.getTree();
  @override
  Future<TodoEntity> update(TodoEntity todo) => _dao.update(todo);

  // ===== 子任务 =====
  @override
  Future<TodoEntity> addSubtask(int parentId, TodoEntity subtask) =>
      _dao.addSubtask(parentId, subtask);
  @override
  Future<List<TodoEntity>> getSubtasks(int parentId) =>
      _dao.getSubtasks(parentId);

  // ===== 删除 =====
  @override
  Future<void> delete(int id) => _dao.softDelete(id);
  @override
  Future<void> cascadeDelete(int id) => _dao.cascadeDelete(id);
  @override
  Future<void> restore(int id) => _dao.restore(id);
  @override
  Future<void> hardDelete(int id) => _dao.hardDelete(id);

  // ===== 重复 =====
  @override
  Future<TodoEntity?> completeRecurring(int id) => _dao.completeRecurring(id);

  // ===== 查询 =====
  @override
  Future<List<TodoEntity>> getByCategory(String c) => _dao.getByCategory(c);
  @override
  Future<List<TodoEntity>> getByStatus(TodoStatus s) => _dao.getByStatus(s);
  @override
  Future<List<TodoEntity>> getByCategoryAndStatus(String c, TodoStatus s) =>
      _dao.getByCategoryAndStatus(c, s);
  @override
  Future<List<TodoEntity>> getByDateRange(DateTime s, DateTime e) =>
      _dao.getByDateRange(s, e);
  @override
  Future<List<TodoEntity>> search(String kw) => _dao.search(kw);
  @override
  Future<List<TodoEntity>> getStarred() => _dao.getStarred();
  @override
  Future<List<TodoEntity>> getToday() => _dao.getToday();
  @override
  Future<List<TodoEntity>> getActive() => _dao.getActive();
  @override
  Future<List<TodoEntity>> getOverdue() => _dao.getOverdue();
  @override
  Future<List<TodoEntity>> getArchived() => _dao.getArchived();
  @override
  Future<List<TodoEntity>> getTrashed() => _dao.getTrashed();

  // ===== 批量 =====
  @override
  Future<void> softClearCompleted() => _dao.softClearCompleted();
  @override
  Future<void> emptyTrash() => _dao.emptyTrash();

  // ===== 统计 =====
  @override
  Future<int> countTodayCompleted() => _dao.countTodayCompleted();
  @override
  Future<int> countTodayTotal() => _dao.countTodayTotal();
  @override
  Future<double> weeklyCompletionRate() => _dao.weeklyCompletionRate();
  @override
  Future<double> delayRate() => _dao.delayRate();

  // ===== 状态 =====
  @override
  Future<TodoEntity> start(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    return _dao.update(
      todo.copyWith(
        status: TodoStatus.inProgress,
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<TodoEntity> complete(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    // 检查是否重复任务
    if (todo.isRecurring) {
      final next = await _dao.completeRecurring(id);
      return next ??
          _dao.update(
            todo.copyWith(
              status: TodoStatus.done,
              completedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
    }
    final now = DateTime.now();
    final actualMinutes = todo.startedAt != null
        ? now.difference(todo.startedAt!).inMinutes
        : null;
    final isDelayed = todo.dueDate != null && now.isAfter(todo.dueDate!);
    // 级联完成子任务
    await _dao.cascadeStatus(id, TodoStatus.done);
    return _dao.update(
      todo.copyWith(
        status: TodoStatus.done,
        completedAt: now,
        actualMinutes: actualMinutes,
        delayCount: todo.delayCount + (isDelayed ? 1 : 0),
        updatedAt: now,
      ),
    );
  }

  @override
  Future<TodoEntity> cancel(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    await _dao.cascadeStatus(id, TodoStatus.cancelled);
    return _dao.update(
      todo.copyWith(
        status: TodoStatus.cancelled,
        cancelledAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> cascadeStatus(int id, TodoStatus status) =>
      _dao.cascadeStatus(id, status);

  @override
  Future<TodoEntity> toggleStar(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    return _dao.update(
      todo.copyWith(isStarred: !todo.isStarred, updatedAt: DateTime.now()),
    );
  }

  @override
  Future<TodoEntity> reopen(int id) async {
    if (await _dao.getById(id) == null) throw Exception('Todo not found');
    await _dao.reopenCascade(id);
    final reopened = await _dao.getById(id);
    if (reopened == null) throw Exception('Todo not found');
    return reopened;
  }
}

/// Riverpod Provider
final todoDaoProvider = FutureProvider<TodoDao>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return TodoDao(db);
});

final todoRepositoryProvider = FutureProvider<TodoRepository>((ref) async {
  final dao = await ref.watch(todoDaoProvider.future);
  return TodoRepositoryImpl(dao);
});
