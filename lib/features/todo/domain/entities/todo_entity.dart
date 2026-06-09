/// 待办事项领域实体。
///
/// 纯 Dart 对象，零依赖。是业务逻辑层（domain）的核心模型。
library;

enum TodoStatus { pending, inProgress, done, cancelled }

/// 默认分类列表（用户可自定义）
const List<String> defaultCategories = ['生活', '工作', '学习', '健康'];

class TodoEntity {
  final int? id;
  final String title;
  final String? description;
  final String category; // 改为 String，不再用 enum
  final int priority; // 1-5
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
  });

  /// 复制并修改部分字段
  TodoEntity copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    int? priority,
    DateTime? dueDate,
    TodoStatus? status,
    List<String>? tags,
    bool? isStarred,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? deletedAt,
    int? actualMinutes,
    int? delayCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      isStarred: isStarred ?? this.isStarred,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      deletedAt: deletedAt ?? this.deletedAt,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      delayCount: delayCount ?? this.delayCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否已过期（未完成且截止日期已过）
  /// 纯日期比对，规避时分秒陷阱。
  /// - 有截止日期：今天严格大于截止日期才算逾期（截止日当天不算）
  /// - 无截止日期：永不逾期（任务自动滚存）
  bool get isOverdue {
    if (status == TodoStatus.done || status == TodoStatus.cancelled) return false;
    if (deletedAt != null) return false;
    if (dueDate == null) return false; // 无截止日期永不逾期
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    // 只有今天严格在截止日期之后才算逾期
    return deadlineDay.isBefore(today);
  }

  /// 是否应该显示在「今天」待办中（即"挪到当天"逻辑）
  bool get shouldShowInToday {
    if (!isActive) return false;
    if (isOverdue) return true; // 逾期任务强制显示

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 有开始日期且开始日期在今天或之前
    if (startedAt != null) {
      final startDay = DateTime(startedAt!.year, startedAt!.month, startedAt!.day);
      if (!startDay.isAfter(today)) return true;
    }

    return false;
  }

  /// 软删除标记
  bool get isDeleted => deletedAt != null;

  /// 是否可恢复（已软删除的待办）
  bool get isRestorable => deletedAt != null;

  /// 是否在进行中
  bool get isInProgress => status == TodoStatus.inProgress;

  /// 是否已完成
  bool get isDone => status == TodoStatus.done;

  /// 是否活跃（待办或进行中，且未删除）
  bool get isActive =>
      (status == TodoStatus.pending || status == TodoStatus.inProgress) &&
      deletedAt == null;

  /// 状态标签（中文）
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
