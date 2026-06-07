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

  @override
  Future<TodoEntity> create(TodoEntity todo) => _dao.insert(todo);

  @override
  Future<TodoEntity?> getById(int id) => _dao.getById(id);

  @override
  Future<List<TodoEntity>> getAll() => _dao.getAll();

  @override
  Future<TodoEntity> update(TodoEntity todo) => _dao.update(todo);

  @override
  Future<void> delete(int id) => _dao.delete(id);

  @override
  @override
  Future<List<TodoEntity>> getByCategory(String category) =>
      _dao.getByCategory(category);

  @override
  Future<List<TodoEntity>> getByStatus(TodoStatus status) =>
      _dao.getByStatus(status);

  @override
  Future<List<TodoEntity>> getByCategoryAndStatus(
    String category,
    TodoStatus status,
  ) =>
      _dao.getByCategoryAndStatus(category, status);

  @override
  Future<List<TodoEntity>> getByDateRange(DateTime start, DateTime end) =>
      _dao.getByDateRange(start, end);

  @override
  Future<List<TodoEntity>> search(String keyword) => _dao.search(keyword);

  @override
  Future<List<TodoEntity>> getStarred() => _dao.getStarred();

  @override
  Future<List<TodoEntity>> getToday() => _dao.getToday();

  @override
  Future<int> countTodayCompleted() => _dao.countTodayCompleted();

  @override
  Future<int> countTodayTotal() => _dao.countTodayTotal();

  @override
  Future<double> weeklyCompletionRate() => _dao.weeklyCompletionRate();

  @override
  Future<double> delayRate() => _dao.delayRate();

  @override
  Future<TodoEntity> start(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    final updated = todo.copyWith(
      status: TodoStatus.inProgress,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _dao.update(updated);
  }

  @override
  Future<TodoEntity> complete(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    final now = DateTime.now();
    // 计算实际耗时
    final actualMinutes = todo.startedAt != null
        ? now.difference(todo.startedAt!).inMinutes
        : null;
    // 检查是否延期
    final isDelayed = todo.dueDate != null && now.isAfter(todo.dueDate!);
    final updated = todo.copyWith(
      status: TodoStatus.done,
      completedAt: now,
      actualMinutes: actualMinutes,
      delayCount: todo.delayCount + (isDelayed ? 1 : 0),
      updatedAt: now,
    );
    return _dao.update(updated);
  }

  @override
  Future<TodoEntity> cancel(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    final updated = todo.copyWith(
      status: TodoStatus.cancelled,
      cancelledAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return _dao.update(updated);
  }

  @override
  Future<TodoEntity> toggleStar(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    final updated = todo.copyWith(
      isStarred: !todo.isStarred,
      updatedAt: DateTime.now(),
    );
    return _dao.update(updated);
  }

  @override
  Future<TodoEntity> reopen(int id) async {
    final todo = await _dao.getById(id);
    if (todo == null) throw Exception('Todo not found');
    final updated = todo.copyWith(
      status: TodoStatus.pending,
      completedAt: null,
      cancelledAt: null,
      updatedAt: DateTime.now(),
    );
    return _dao.update(updated);
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
