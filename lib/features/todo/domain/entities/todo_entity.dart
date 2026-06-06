/// 待办事项领域实体。
///
/// 纯 Dart 对象，零依赖。是业务逻辑层（domain）的核心模型。
library;

enum TodoCategory { life, work }

enum TodoStatus { pending, inProgress, done, cancelled }

class TodoEntity {
  final int? id;
  final String title;
  final String? description;
  final TodoCategory category;
  final int priority; // 1-5
  final DateTime? dueDate;
  final TodoStatus status;
  final List<String> tags;
  final bool isStarred;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int? actualMinutes;
  final int delayCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodoEntity({
    this.id,
    required this.title,
    this.description,
    this.category = TodoCategory.life,
    this.priority = 3,
    this.dueDate,
    this.status = TodoStatus.pending,
    this.tags = const [],
    this.isStarred = false,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
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
    TodoCategory? category,
    int? priority,
    DateTime? dueDate,
    TodoStatus? status,
    List<String>? tags,
    bool? isStarred,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
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
      actualMinutes: actualMinutes ?? this.actualMinutes,
      delayCount: delayCount ?? this.delayCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否已过期（未完成且截止日期已过）
  bool get isOverdue =>
      dueDate != null &&
      status != TodoStatus.done &&
      status != TodoStatus.cancelled &&
      dueDate!.isBefore(DateTime.now());

  /// 是否在进行中
  bool get isInProgress => status == TodoStatus.inProgress;

  /// 是否已完成
  bool get isDone => status == TodoStatus.done;

  /// 分类标签（中文）
  String get categoryLabel => category == TodoCategory.life ? '生活' : '工作';

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
