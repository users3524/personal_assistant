/// 待办事项领域实体。
///
/// 纯 Dart 对象，零依赖。是业务逻辑层（domain）的核心模型。
library;

enum TodoStatus { pending, inProgress, done, cancelled }

/// 默认分类列表（用户可自定义）
const List<String> defaultCategories = ['生活', '工作', '学习', '健康'];

const Object _copySentinel = Object();

class TodoListEntity {
  final int? id;
  final String name;
  final String category;
  final DateTime createdAt;

  const TodoListEntity({
    this.id,
    required this.name,
    required this.category,
    required this.createdAt,
  });

  TodoListEntity copyWith({
    int? id,
    String? name,
    String? category,
    DateTime? createdAt,
  }) => TodoListEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    createdAt: createdAt ?? this.createdAt,
  );
}

class TodoEntity {
  final int? id;
  final String title;
  final String? description;
  final String category;
  final int priority;
  final DateTime? dueDate;
  final TodoStatus status;
  final List<String> tags;
  final bool isStarred;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? deletedAt;
  final int? actualMinutes;
  final int delayCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 清单+层级
  final int? listId;
  final int? parentId;
  final List<TodoEntity> subtasks;

  // 重复策略
  final String? recurrenceRule;

  const TodoEntity({
    this.id,
    required this.title,
    this.description,
    this.category = '生活',
    this.priority = 3,
    this.dueDate,
    this.status = TodoStatus.pending,
    this.tags = const [],
    this.isStarred = false,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.deletedAt,
    this.actualMinutes,
    this.delayCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.listId,
    this.parentId,
    this.subtasks = const [],
    this.recurrenceRule,
  });

  TodoEntity copyWith({
    Object? id = _copySentinel,
    String? title,
    Object? description = _copySentinel,
    String? category,
    int? priority,
    Object? dueDate = _copySentinel,
    TodoStatus? status,
    List<String>? tags,
    bool? isStarred,
    Object? startedAt = _copySentinel,
    Object? completedAt = _copySentinel,
    Object? cancelledAt = _copySentinel,
    Object? deletedAt = _copySentinel,
    Object? actualMinutes = _copySentinel,
    int? delayCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? listId = _copySentinel,
    Object? parentId = _copySentinel,
    List<TodoEntity>? subtasks,
    Object? recurrenceRule = _copySentinel,
  }) => TodoEntity(
    id: id == _copySentinel ? this.id : id as int?,
    title: title ?? this.title,
    description: description == _copySentinel
        ? this.description
        : description as String?,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    dueDate: dueDate == _copySentinel ? this.dueDate : dueDate as DateTime?,
    status: status ?? this.status,
    tags: tags ?? this.tags,
    isStarred: isStarred ?? this.isStarred,
    startedAt: startedAt == _copySentinel
        ? this.startedAt
        : startedAt as DateTime?,
    completedAt: completedAt == _copySentinel
        ? this.completedAt
        : completedAt as DateTime?,
    cancelledAt: cancelledAt == _copySentinel
        ? this.cancelledAt
        : cancelledAt as DateTime?,
    deletedAt: deletedAt == _copySentinel
        ? this.deletedAt
        : deletedAt as DateTime?,
    actualMinutes: actualMinutes == _copySentinel
        ? this.actualMinutes
        : actualMinutes as int?,
    delayCount: delayCount ?? this.delayCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    listId: listId == _copySentinel ? this.listId : listId as int?,
    parentId: parentId == _copySentinel ? this.parentId : parentId as int?,
    subtasks: subtasks ?? this.subtasks,
    recurrenceRule: recurrenceRule == _copySentinel
        ? this.recurrenceRule
        : recurrenceRule as String?,
  );

  // ===== 核心逻辑属性 =====

  /// 是否已过期（纯日期比对）
  bool get isOverdue {
    if (status == TodoStatus.done || status == TodoStatus.cancelled) {
      return false;
    }
    if (deletedAt != null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (dueDate != null) {
      final deadlineDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
      return deadlineDay.isBefore(today);
    }
    if (startedAt != null) {
      final startDay = DateTime(
        startedAt!.year,
        startedAt!.month,
        startedAt!.day,
      );
      return startDay.isBefore(today);
    }
    return false;
  }

  DateTime get displayDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (status == TodoStatus.done && completedAt != null) return completedAt!;
    if (status == TodoStatus.cancelled && cancelledAt != null) {
      return cancelledAt!;
    }
    if (startedAt != null) {
      final startDay = DateTime(
        startedAt!.year,
        startedAt!.month,
        startedAt!.day,
      );
      if (today.isAfter(startDay)) return today;
      return startDay;
    }
    return createdAt;
  }

  bool get shouldShowInToday {
    if (!isActive) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDisplayDay = DateTime(
      displayDate.year,
      displayDate.month,
      displayDate.day,
    );
    return itemDisplayDay == today;
  }

  // 层级判断
  bool get isParent => parentId == null;
  bool get isSubtask => parentId != null;

  // 子任务进度
  double get subtaskProgress {
    if (subtasks.isEmpty) return 0.0;
    final done = subtasks.where((s) => s.status == TodoStatus.done).length;
    return done / subtasks.length;
  }

  bool get isDeleted => deletedAt != null;
  bool get isRestorable => deletedAt != null;
  bool get isInProgress => status == TodoStatus.inProgress;
  bool get isDone => status == TodoStatus.done;
  bool get isActive =>
      (status == TodoStatus.pending || status == TodoStatus.inProgress) &&
      deletedAt == null;

  /// 是否有重复策略
  bool get isRecurring => recurrenceRule != null && recurrenceRule!.isNotEmpty;

  String get statusLabel {
    switch (status) {
      case TodoStatus.pending:
        return '待办';
      case TodoStatus.inProgress:
        return '进行中';
      case TodoStatus.done:
        return '已完成';
      case TodoStatus.cancelled:
        return '已取消';
    }
  }
}
