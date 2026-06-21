/// 待办 DAO — drift 数据库操作。
library;

import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/todo_entity.dart';
import '../datasources/todos_table.dart';

class TodoDao {
  final AppDatabase _db;

  TodoDao(this._db);

  // ===== 清单 CRUD =====

  Future<List<TodoListEntity>> getLists() async {
    final rows = await (_db.select(
      _db.todoLists,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
    return rows
        .map(
          (r) => TodoListEntity(
            id: r.id,
            name: r.name,
            category: r.category,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  Future<TodoListEntity> saveList(TodoListEntity list) async {
    if (list.id != null) {
      await (_db.update(
        _db.todoLists,
      )..where((t) => t.id.equals(list.id!))).write(
        TodoListsCompanion(
          name: Value(list.name),
          category: Value(list.category),
        ),
      );
      return list;
    }
    final id = await _db
        .into(_db.todoLists)
        .insert(
          TodoListsCompanion(
            name: Value(list.name),
            category: Value(list.category),
            createdAt: Value(list.createdAt),
          ),
        );
    return list.copyWith(id: id);
  }

  Future<void> deleteList(int id) async {
    await _db.transaction(() async {
      await (_db.update(_db.todos)..where((t) => t.listId.equals(id))).write(
        TodosCompanion(
          listId: const Value<int?>(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (_db.delete(_db.todoLists)..where((t) => t.id.equals(id))).go();
    });
  }

  // ===== 实体转换 =====

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
      listId: Value(entity.listId),
      parentId: Value(entity.parentId),
      recurrenceRule: Value(entity.recurrenceRule),
    );
  }

  TodoEntity _toEntity(Todo row, {List<TodoEntity> subtasks = const []}) {
    return TodoEntity(
      id: row.id,
      title: row.title,
      description: row.description,
      category: _normalizeCategory(row.category),
      priority: row.priority,
      dueDate: row.dueDate,
      status: _statusFromString(row.status),
      tags: row.tags,
      isStarred: row.isStarred,
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      cancelledAt: row.cancelledAt,
      deletedAt: row.deletedAt,
      actualMinutes: row.actualMinutes,
      delayCount: row.delayCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      listId: row.listId,
      parentId: row.parentId,
      recurrenceRule: row.recurrenceRule,
      subtasks: subtasks,
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

  // ===== 树形查询 =====

  /// 获取父任务及其子任务树
  Future<TodoEntity?> _hydrateTree(Todo? row) async {
    if (row == null) return null;
    final childRows =
        await (_db.select(_db.todos)
              ..where((t) => t.parentId.equals(row.id) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    final children = childRows.map((r) => _toEntity(r)).toList();
    return _toEntity(row, subtasks: children);
  }

  Future<List<TodoEntity>> _hydrateParentRows(List<Todo> parentRows) async {
    if (parentRows.isEmpty) return const [];

    final parentIds = parentRows.map((row) => row.id).toList();
    final childRows =
        await (_db.select(_db.todos)
              ..where((t) => t.parentId.isIn(parentIds) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();

    final childrenByParent = <int, List<TodoEntity>>{};
    for (final row in childRows) {
      final parentId = row.parentId;
      if (parentId == null) continue;
      childrenByParent.putIfAbsent(parentId, () => []).add(_toEntity(row));
    }

    return parentRows
        .map(
          (row) =>
              _toEntity(row, subtasks: childrenByParent[row.id] ?? const []),
        )
        .toList();
  }

  /// 获取所有父任务（树形结构）
  Future<List<TodoEntity>> getTree() async {
    final parentRows =
        await (_db.select(_db.todos)
              ..where((t) => t.parentId.isNull() & t.deletedAt.isNull())
              ..orderBy(_smartOrder()))
            .get();
    return _hydrateParentRows(parentRows);
  }

  /// 获取今日任务树
  Future<List<TodoEntity>> getTodayTree() async {
    final all = await getTree();
    return all.where((e) => e.shouldShowInToday).toList();
  }

  /// 获取父任务（不含子任务，用于仪表盘统计）
  Future<List<TodoEntity>> getParents() async {
    final rows =
        await (_db.select(_db.todos)
              ..where((t) => t.parentId.isNull() & t.deletedAt.isNull())
              ..orderBy(_smartOrder()))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  // ===== 基础 CRUD =====

  Future<TodoEntity> insert(TodoEntity entity) async {
    final id = await _db.into(_db.todos).insert(_toCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<TodoEntity?> getById(int id) async {
    final row = await (_db.select(
      _db.todos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _hydrateTree(row);
  }

  Future<List<TodoEntity>> getAll() => getTree();

  Future<TodoEntity> update(TodoEntity entity) async {
    await (_db.update(_db.todos)..where((t) => t.id.equals(entity.id!))).write(
      _toCompanion(entity).copyWith(updatedAt: Value(DateTime.now())),
    );
    return entity;
  }

  // ===== 子任务 CRUD =====

  Future<TodoEntity> addSubtask(int parentId, TodoEntity subtask) async {
    final entity = subtask.copyWith(parentId: parentId);
    final id = await _db.into(_db.todos).insert(_toCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<List<TodoEntity>> getSubtasks(int parentId) async {
    final rows =
        await (_db.select(_db.todos)
              ..where((t) => t.parentId.equals(parentId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  // ===== 级联状态更新 =====

  Future<void> cascadeStatus(int id, TodoStatus newStatus) async {
    final now = DateTime.now();
    final statusStr = _statusToString(newStatus);
    final companion = TodosCompanion(
      status: Value(statusStr),
      updatedAt: Value(now),
      completedAt: newStatus == TodoStatus.done
          ? Value(now)
          : const Value.absent(),
      cancelledAt: newStatus == TodoStatus.cancelled
          ? Value(now)
          : const Value.absent(),
    );
    await _db.transaction(() async {
      await (_db.update(
        _db.todos,
      )..where((t) => t.id.equals(id))).write(companion);
      await (_db.update(_db.todos)
            ..where((t) => t.parentId.equals(id) & t.deletedAt.isNull()))
          .write(companion);
    });
  }

  Future<void> cascadeDelete(int id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.todos)..where((t) => t.id.equals(id))).write(
        TodosCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(_db.todos)..where((t) => t.parentId.equals(id))).write(
        TodosCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  // ===== 重复策略 =====

  /// 完成一个重复任务：归档当前，生成下一个
  Future<TodoEntity?> completeRecurring(int id) async {
    final todo = await getById(id);
    if (todo == null || todo.recurrenceRule == null) return null;

    // 计算下次截止日期
    final nextDue = _nextRecurrenceDate(
      todo.recurrenceRule!,
      todo.dueDate ?? DateTime.now(),
    );
    if (nextDue == null) return null;

    // 归档当前
    final now = DateTime.now();
    await (_db.update(_db.todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        status: const Value('done'),
        completedAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // 创建下一周期的副本
    final next = todo.copyWith(
      id: null,
      status: TodoStatus.pending,
      dueDate: nextDue,
      startedAt: nextDue,
      completedAt: null,
      cancelledAt: null,
      actualMinutes: null,
      delayCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    return insert(next);
  }

  DateTime? _nextRecurrenceDate(String rule, DateTime from) {
    switch (rule) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(from.year, from.month + 1, from.day);
      default:
        return null;
    }
  }

  // ===== 软删除与恢复 =====

  Future<void> softDelete(int id) => cascadeDelete(id);

  Future<void> restore(int id) async {
    await (_db.update(_db.todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        deletedAt: const Value(null),
        status: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reopenCascade(int id) async {
    final now = DateTime.now();
    const companion = TodosCompanion(
      status: Value('pending'),
      completedAt: Value<DateTime?>(null),
      cancelledAt: Value<DateTime?>(null),
    );
    await _db.transaction(() async {
      await (_db.update(_db.todos)..where((t) => t.id.equals(id))).write(
        companion.copyWith(updatedAt: Value(now)),
      );
      await (_db.update(_db.todos)
            ..where((t) => t.parentId.equals(id) & t.deletedAt.isNull()))
          .write(companion.copyWith(updatedAt: Value(now)));
    });
  }

  Future<void> hardDelete(int id) async {
    await _db.transaction(() async {
      final todoIds = await _todoAndDirectChildIds(id);
      if (todoIds.isNotEmpty) {
        await (_db.delete(_db.milestoneRelations)..where(
              (t) => t.sourceType.equals('todo') & t.sourceId.isIn(todoIds),
            ))
            .go();
      }
      await (_db.delete(
        _db.todos,
      )..where((t) => t.id.equals(id) | t.parentId.equals(id))).go();
    });
  }

  // ===== 智能排序 =====

  List<OrderingTerm Function(Todos t)> _smartOrder() => [
    (t) => OrderingTerm.desc(t.isStarred),
    (t) => OrderingTerm.desc(t.priority),
    (t) => OrderingTerm.asc(t.dueDate),
    (t) => OrderingTerm.desc(t.updatedAt),
  ];

  // ===== 查询 =====

  Future<List<TodoEntity>> getByCategory(String category) async {
    final rows =
        await (_db.select(_db.todos)
              ..where(
                (t) =>
                    t.category.equals(category) &
                    t.deletedAt.isNull() &
                    t.parentId.isNull(),
              )
              ..orderBy(_smartOrder()))
            .get();
    return _hydrateParentRows(rows);
  }

  Future<List<TodoEntity>> getByStatus(TodoStatus status) async {
    final statusStr = _statusToString(status);
    final rows =
        await (_db.select(_db.todos)
              ..where(
                (t) =>
                    t.status.equals(statusStr) &
                    t.deletedAt.isNull() &
                    t.parentId.isNull(),
              )
              ..orderBy(_smartOrder()))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  Future<List<TodoEntity>> getByCategoryAndStatus(
    String category,
    TodoStatus status,
  ) async {
    final statusStr = _statusToString(status);
    final rows =
        await (_db.select(_db.todos)
              ..where(
                (t) =>
                    t.category.equals(category) &
                    t.status.equals(statusStr) &
                    t.deletedAt.isNull() &
                    t.parentId.isNull(),
              )
              ..orderBy(_smartOrder()))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  Future<List<TodoEntity>> getByDateRange(DateTime start, DateTime end) async {
    final rows =
        await (_db.select(_db.todos)
              ..where(
                (t) =>
                    t.dueDate.isBetweenValues(start, end) &
                    t.deletedAt.isNull() &
                    t.parentId.isNull(),
              )
              ..orderBy(_smartOrder()))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  Future<List<TodoEntity>> search(String keyword) async {
    final pattern = '%$keyword%';
    final rows =
        await (_db.select(_db.todos)
              ..where(
                (t) =>
                    (t.title.like(pattern) | t.description.like(pattern)) &
                    t.deletedAt.isNull() &
                    t.parentId.isNull(),
              )
              ..orderBy(_smartOrder()))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  Future<List<TodoEntity>> getStarred() async {
    final rows =
        await (_db.select(_db.todos)
              ..where(
                (t) =>
                    t.isStarred.equals(true) &
                    t.deletedAt.isNull() &
                    t.parentId.isNull(),
              )
              ..orderBy(_smartOrder()))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  Future<List<TodoEntity>> getToday() async {
    final all = await getTree();
    return all.where((e) => e.shouldShowInToday).toList();
  }

  Future<List<TodoEntity>> getActive() async {
    final all = await getTree();
    return all.where((e) => !e.isOverdue && e.isActive).toList();
  }

  Future<List<TodoEntity>> getOverdue() async {
    final all = await getTree();
    return all.where((e) => e.isOverdue).toList();
  }

  Future<List<TodoEntity>> getArchived() async {
    final rows =
        await (_db.select(_db.todos)
              ..where(
                (t) =>
                    t.status.isIn(['done', 'cancelled']) &
                    t.deletedAt.isNull() &
                    t.parentId.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  Future<List<TodoEntity>> getTrashed() async {
    final rows =
        await (_db.select(_db.todos)
              ..where((t) => t.deletedAt.isNotNull() & t.parentId.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
            .get();
    return rows.map((r) => _toEntity(r)).toList();
  }

  // ===== 批量 =====

  Future<void> softClearCompleted() async {
    final now = DateTime.now();
    await (_db.update(_db.todos)
          ..where((t) => t.status.equals('done') & t.deletedAt.isNull()))
        .write(TodosCompanion(updatedAt: Value(now), deletedAt: Value(now)));
  }

  Future<void> emptyTrash() async {
    await _db.transaction(() async {
      final trashedIds = await _trashedTodoIds();
      if (trashedIds.isNotEmpty) {
        await (_db.delete(_db.milestoneRelations)..where(
              (t) => t.sourceType.equals('todo') & t.sourceId.isIn(trashedIds),
            ))
            .go();
      }
      await (_db.delete(_db.todos)..where((t) => t.deletedAt.isNotNull())).go();
    });
  }

  // ===== 统计（仅父任务） =====

  Future<int> countTodayCompleted() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final rows =
        await (_db.select(_db.todos)..where(
              (t) =>
                  t.status.equals('done') &
                  _dateInHalfOpenRange(t.completedAt, todayStart, todayEnd) &
                  t.deletedAt.isNull() &
                  t.parentId.isNull(),
            ))
            .get();
    return rows.length;
  }

  Future<int> countTodayTotal() async {
    final completedCount = await countTodayCompleted();
    final activeRows =
        await (_db.select(_db.todos)..where(
              (t) =>
                  t.status.isNotIn(['done', 'cancelled']) &
                  t.deletedAt.isNull() &
                  t.parentId.isNull(),
            ))
            .get();
    final activeEntities = activeRows.map((r) => _toEntity(r)).toList();
    final activeTodayCount = activeEntities
        .where((e) => e.shouldShowInToday)
        .length;
    return completedCount + activeTodayCount;
  }

  Future<double> weeklyCompletionRate() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEndDate = weekStartDate.add(const Duration(days: 7));
    final all =
        await (_db.select(_db.todos)..where(
              (t) =>
                  _dateInHalfOpenRange(
                    t.createdAt,
                    weekStartDate,
                    weekEndDate,
                  ) &
                  t.deletedAt.isNull() &
                  t.parentId.isNull(),
            ))
            .get();
    if (all.isEmpty) return 1.0;
    final done = all.where((t) => t.status == 'done').length;
    return done / all.length;
  }

  Future<double> delayRate() async {
    final done =
        await (_db.select(_db.todos)..where(
              (t) =>
                  t.status.equals('done') &
                  t.deletedAt.isNull() &
                  t.parentId.isNull(),
            ))
            .get();
    if (done.isEmpty) return 0.0;
    final delayed = done.where((t) {
      if (t.completedAt == null || t.dueDate == null) return false;
      return t.completedAt!.isAfter(t.dueDate!);
    }).length;
    return delayed / done.length;
  }

  Expression<bool> _dateInHalfOpenRange(
    DateTimeColumn column,
    DateTime start,
    DateTime end,
  ) {
    return column.isBiggerOrEqualValue(start) & column.isSmallerThanValue(end);
  }

  Future<List<int>> _todoAndDirectChildIds(int id) async {
    final rows = await (_db.select(
      _db.todos,
    )..where((t) => t.id.equals(id) | t.parentId.equals(id))).get();
    return rows.map((row) => row.id).toList();
  }

  Future<List<int>> _trashedTodoIds() async {
    final rows = await (_db.select(
      _db.todos,
    )..where((t) => t.deletedAt.isNotNull())).get();
    return rows.map((row) => row.id).toList();
  }
}
