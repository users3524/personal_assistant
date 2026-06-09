/// 待办 DAO — drift 数据库操作。
library;

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/todo_entity.dart';
import '../datasources/todos_table.dart';

/// 待办数据访问对象
class TodoDao {
  final AppDatabase _db;

  TodoDao(this._db);

  /// 将领域实体转为 drift 插入数据
  TodosCompanion _toCompanion(TodoEntity entity) {
    return TodosCompanion(
      title: Value(entity.title),
      description: Value(entity.description),
      category: Value(entity.category),
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
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
      deletedAt: Value(entity.deletedAt),
    );
  }

  /// 将数据库行转为领域实体
  TodoEntity _toEntity(Todo row) {
    final cat = _normalizeCategory(row.category);
    final tags = row.tags;
    return TodoEntity(
      id: row.id,
      title: row.title,
      description: row.description,
      category: cat,
      priority: row.priority,
      dueDate: row.dueDate,
      status: _statusFromString(row.status),
      tags: tags,
      isStarred: row.isStarred,
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      cancelledAt: row.cancelledAt,
      deletedAt: row.deletedAt,
      actualMinutes: row.actualMinutes,
      delayCount: row.delayCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _normalizeCategory(String cat) {
    switch (cat) {
      case 'life':
        return '生活';
      case 'work':
        return '工作';
      default:
        return cat;
    }
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
    final row = await (_db.select(_db.todos)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _toEntity(row) : null;
  }

  Future<List<TodoEntity>> getAll() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
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

  // ===== 软删除与恢复 =====

  /// 软删除：设置 deletedAt 时间戳
  Future<void> softDelete(int id) async {
    await (_db.update(_db.todos)
          ..where((t) => t.id.equals(id)))
        .write(TodosCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
  }

  /// 恢复软删除
  Future<void> restore(int id) async {
    await (_db.update(_db.todos)
          ..where((t) => t.id.equals(id)))
        .write(TodosCompanion(
          deletedAt: Value(null),
          status: Value('pending'),
          updatedAt: Value(DateTime.now()),
        ));
  }

  /// 永久删除
  Future<void> hardDelete(int id) async {
    await (_db.delete(_db.todos)..where((t) => t.id.equals(id))).go();
  }

  // ===== 智能排序 =====

  /// 星标优先 → 优先级降序 → 截止日期升序 → 更新时间降序
  List<OrderingTerm Function(Todos t)> _smartOrder() => [
        (t) => OrderingTerm.desc(t.isStarred),
        (t) => OrderingTerm.desc(t.priority),
        (t) => OrderingTerm.asc(t.dueDate),
        (t) => OrderingTerm.desc(t.updatedAt),
      ];

  // ===== 条件查询 =====

  Future<List<TodoEntity>> getByCategory(String category) async {
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.category.equals(category) & t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getByStatus(TodoStatus status) async {
    final statusStr = _statusToString(status);
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.status.equals(statusStr) & t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getByCategoryAndStatus(
    String category,
    TodoStatus status,
  ) async {
    final statusStr = _statusToString(status);
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.category.equals(category) &
              t.status.equals(statusStr) &
              t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.dueDate.isBetweenValues(start, end) & t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> search(String keyword) async {
    final pattern = '%$keyword%';
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              (t.title.like(pattern) | t.description.like(pattern)) &
              t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<TodoEntity>> getStarred() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.isStarred.equals(true) & t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).toList();
  }

  /// 今日待办：截止日期为今天且未完成
  /// 今日待办：所有应显示在今天的未完成任务（使用 shouldShowInToday 过滤）
  Future<List<TodoEntity>> getToday() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.status.isNotIn(['done', 'cancelled']) &
              t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).where((e) => e.shouldShowInToday).toList();
  }

  /// 活跃待办：未完成、未逾期、未删除
  Future<List<TodoEntity>> getActive() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.status.isNotIn(['done', 'cancelled']) &
              t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).where((e) => !e.isOverdue).toList();
  }

  /// 逾期待办：有截止日期且已过截止日（由实体 isOverdue 判定）
  Future<List<TodoEntity>> getOverdue() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.status.isNotIn(['done', 'cancelled']) &
              t.deletedAt.isNull())
          ..orderBy(_smartOrder()))
        .get();
    return rows.map(_toEntity).where((e) => e.isOverdue).toList();
  }

  /// 归档：已完成或已取消（不含已删除）
  Future<List<TodoEntity>> getArchived() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.status.isIn(['done', 'cancelled']) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  /// 回收站：已软删除
  Future<List<TodoEntity>> getTrashed() async {
    final rows = await (_db.select(_db.todos)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  // ===== 批量操作 =====

  /// 已完成任务移至回收站
  Future<void> softClearCompleted() async {
    await (_db.update(_db.todos)
          ..where((t) => t.status.equals('done') & t.deletedAt.isNull()))
        .write(TodosCompanion(
          updatedAt: Value(DateTime.now()),
          deletedAt: Value(DateTime.now()),
        ));
  }

  /// 清空回收站
  Future<void> emptyTrash() async {
    await (_db.delete(_db.todos)..where((t) => t.deletedAt.isNotNull())).go();
  }

  // ===== 统计 =====

  Future<int> countTodayCompleted() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.status.equals('done') &
              t.completedAt.isBetweenValues(todayStart, todayEnd) &
              t.deletedAt.isNull()))
        .get();
    return rows.length;
  }

  Future<int> countTodayTotal() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final rows = await (_db.select(_db.todos)
          ..where((t) =>
              t.createdAt.isBetweenValues(todayStart, todayEnd) &
              t.deletedAt.isNull()))
        .get();
    return rows.length;
  }

  Future<double> weeklyCompletionRate() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEndDate = weekStartDate.add(const Duration(days: 7));

    final all = await (_db.select(_db.todos)
          ..where((t) =>
              t.createdAt.isBetweenValues(weekStartDate, weekEndDate) &
              t.deletedAt.isNull()))
        .get();
    if (all.isEmpty) return 1.0;

    final done = all.where((t) => t.status == 'done').length;
    return done / all.length;
  }

  Future<double> delayRate() async {
    final done = await (_db.select(_db.todos)
          ..where((t) => t.status.equals('done') & t.deletedAt.isNull()))
        .get();
    if (done.isEmpty) return 0.0;

    final delayed = done.where((t) {
      if (t.completedAt == null || t.dueDate == null) return false;
      return t.completedAt!.isAfter(t.dueDate!);
    }).length;
    return delayed / done.length;
  }
}
