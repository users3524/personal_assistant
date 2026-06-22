/// 待办列表视图 — 支持滑动操作。
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../domain/entities/todo_entity.dart';

class TodoListView extends StatelessWidget {
  final List<TodoEntity> todos;
  final Function(TodoEntity) onToggle;
  final Function(TodoEntity) onDelete;
  final Function(TodoEntity) onTap;

  const TodoListView({
    super.key,
    required this.todos,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.task_alt,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无待办',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右下角 + 新建待办',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    // 分组：未完成在前，已完成在后
    final pending = todos
        .where((t) => !t.isDone && t.status != TodoStatus.cancelled)
        .toList();
    final done = todos.where((t) => t.isDone).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: pending.length + (done.isNotEmpty ? done.length + 1 : 0),
      itemBuilder: (context, index) {
        // 已完成分组标题
        if (index == pending.length && done.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
            child: Text(
              '已完成 (${done.length})',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final todo = index < pending.length
            ? pending[index]
            : done[index - pending.length - (done.isNotEmpty ? 1 : 0)];

        return _TodoListTile(
          todo: todo,
          onToggle: () => onToggle(todo),
          onDelete: () => onDelete(todo),
          onTap: () => onTap(todo),
        );
      },
    );
  }
}

class _TodoListTile extends StatelessWidget {
  final TodoEntity todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _TodoListTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = todo.category == '工作'
        ? AppColors.blue
        : todo.category == '生活'
        ? AppColors.green
        : AppColors.primary;

    return Dismissible(
      key: ValueKey(
        'todo_list_view_${todo.id ?? todo.createdAt.microsecondsSinceEpoch}',
      ),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: todo.isDone ? AppColors.orange : AppColors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          todo.isDone ? Icons.undo : Icons.check,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggle();
          return false; // 我们自己处理状态变更
        }
        onDelete();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppSurfaceCard(
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: GestureDetector(
              onTap: todo.isDone ? null : onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: todo.isDone ? color : Colors.transparent,
                  border: Border.all(
                    color: todo.isDone ? color : AppColors.line,
                    width: 2,
                  ),
                ),
                child: todo.isDone
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            title: Text(
              todo.title,
              style: TextStyle(
                decoration: todo.isDone ? TextDecoration.lineThrough : null,
                color: todo.isDone ? AppColors.muted : AppColors.ink,
                fontWeight: todo.isDone ? FontWeight.normal : FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _TodoMetaChip(label: todo.category, color: color),
                  if (todo.dueDate != null)
                    _TodoMetaChip(
                      label: '${todo.dueDate!.month}/${todo.dueDate!.day}',
                      color: AppColors.muted,
                      icon: Icons.event,
                    ),
                  if (todo.isOverdue)
                    const _TodoMetaChip(
                      label: '逾期',
                      color: AppColors.red,
                      icon: Icons.warning_amber,
                      isStrong: true,
                    ),
                ],
              ),
            ),
            trailing: todo.isDone
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (todo.priority > 3)
                        const Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: AppColors.red,
                        ),
                      if (todo.isStarred)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: AppColors.gold,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TodoMetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool isStrong;

  const _TodoMetaChip({
    required this.label,
    required this.color,
    this.icon,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isStrong ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: isStrong ? Colors.white : color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isStrong ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}
