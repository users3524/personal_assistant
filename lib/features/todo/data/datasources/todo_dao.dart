/// 待办 DAO — drift 数据库操作。
///
/// 使用 drift 的类型安全查询 API。
library;

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/todo_entity.dart';

/// 待办数据访问对象
class TodoDao {
  final AppDatabase _db;

  TodoDao(this._db);

  /// 将领域实体转为 drift 插入数据
  TodosCompanion _toCompanion(TodoEntity entity) {
    return TodosCompanion(
      title: Value(entity.title),
      description: Value(entity.description),
      category: Value(entity.category == TodoCategory.life ? 'life' : 'work'),
      priority: Value(entity.priority),
      dueDate: Value(entity.dueDate),
      status: Value(_statusToString(entity.status)),
      tags: Value(entity.tags),
      isStarred: Value(entity.isStarred),
      startedAt: Value(entity.startedAt),
      completedAt: Value(entity.completedAt),
      cancelledAt: Value(entity.cancelledAt),
      actualMinutes: Value(entity.actualMinutes),
      delayCount: Value(entity.delayCount),
    );
  }

  /// 将数据库行转为领域实体
  TodoEntity _toEntity(TodoRow row) {
    return TodoEntity(
      id: row.id,
      title: row.title,
      description: row.description,
      category: row.category == 'life' ? TodoCategory.life : TodoCategory.work,
      priority: row.priority,
      dueDate: row.dueDate,
      status: _statusFromString(row.status),
      tags: row.tags,
      isStarred: row.isStarred,
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      cancelledAt: row.cancelledAt,
      actualMinutes: row.actualMinutes,
      delayCount: row.delayCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _statusToString(TodoStatus status) {
    switch (status) {
      case TodoStatus.pending:
        return 'pending';
      case TodoStatus.inProgress:
        return 'in_progress';
      case TodoStatus.done:
        return 'done';
      case TodoStatus.cancelled:
        return 'cancelled';
    }
  }

  TodoStatus _statusFromString(String status) {
    switch (status) {
      case 'pending':
        return TodoStatus.pending;
      case 'in_progress':
        return TodoStatus.inProgress;
      case 'done':
        return TodoStatus.done;
      case 'cancelled':
        return TodoStatus.cancelled;
      default:
        return TodoStatus.pending;
    }
  }

  // ===== 基础 CRUD =====

  Future<TodoEntity> insert(TodoEntity entity) async {
    final id = await _db.into(_db.todos).insert(_toCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<TodoEntity?> getById(int id) async {
    final row = await (_db.select(_db.todos)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _toEntity(row) : null;
  }

  Future<List<TodoEntity>> getAll() async {
    final rows = await _db.select(_db.todos).get();
    return rows.map(_toEntity).toList();
  }

  Future<TodoEntity> update(TodoEntity entity) async {
    await (_db.update(_db.todos)
          ..where((t) => t.id.equals(entity.id!)))
        .write(_toCompanion(entity).copyWith(
          updatedAt: Value(DateTime.now()),
        ));
    return entity;
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.todos)..where((t) => t.id.equals(id))).go();
  }

  // ===== 查询 =====

  Future<List<TodoEntity>> getByCategory(TodoCategory category) async {
    final catStr = category == TodoCategory.life ? 'life' : 'work';
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.category.equals(catStr))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getByStatus(TodoStatus status) async {
    final statusStr = _statusToString(status);
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.status.equals(statusStr))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getByCategoryAndStatus(
    TodoCategory category,
    TodoStatus status,
  ) async {
    final catStr = category == TodoCategory.life ? 'life' : 'work';
    final statusStr = _statusToString(status);
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.category.equals(catStr) & t.status.equals(statusStr))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.createdAt.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> search(String keyword) async {
    final pattern = '%$keyword%';
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.title.like(pattern) | t.description.like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getStarred() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.isStarred.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getToday() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.createdAt.isBetweenValues(todayStart, todayEnd))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  // ===== 统计 =====

  Future<int> countTodayCompleted() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final count = await (_db.select(_db.todos)
          ..where((t) =>
              t.status.equals('done') &
              t.completedAt.isBetweenValues(todayStart, todayEnd)))
        .get();
    return count.length;
  }

  Future<int> countTodayTotal() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final count = await (_db.select(_db.todos)
          ..where((t) =>
              t.createdAt.isBetweenValues(todayStart, todayEnd)))
        .get();
    return count.length;
  }

  Future<double> weeklyCompletionRate() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEndDate =
        weekStartDate.add(const Duration(days: 7));

    final all = await (_db.select(_db.todos)
          ..where((t) =>
              t.createdAt.isBetweenValues(weekStartDate, weekEndDate)))
        .get();
    if (all.isEmpty) return 1.0;

    final done = all.where((t) => t.status == 'done').length;
    return done / all.length;
  }

  Future<double> delayRate() async {
    final done = await (_db.select(_db.todos)
          ..where((t) => t.status.equals('done')))
        .get();
    if (done.isEmpty) return 0.0;

    final delayed = done.where((t) {
      if (t.completedAt == null || t.dueDate == null) return false;
      return t.completedAt!.isAfter(t.dueDate!);
    }).length;
    return delayed / done.length;
  }
}
