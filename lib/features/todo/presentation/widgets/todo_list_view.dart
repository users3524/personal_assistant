/// 待办列表视图 — 支持滑动操作。
library;

import 'package:flutter/material.dart';

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
            Icon(Icons.task_alt,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              '暂无待办',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角 + 新建待办',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      );
    }

    // 分组：未完成在前，已完成在后
    final pending =
        todos.where((t) => !t.isDone && t.status != TodoStatus.cancelled).toList();
    final done = todos.where((t) => t.isDone).toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: pending.length + (done.isNotEmpty ? done.length + 1 : 0),
      itemBuilder: (context, index) {
        // 已完成分组标题
        if (index == pending.length && done.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '已完成 (${done.length})',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.grey,
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
    final color = todo.category == TodoCategory.life ? Colors.green : Colors.blue;

    return Dismissible(
      key: ValueKey(todo.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.green,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggle();
          return false; // 我们自己处理状态变更
        }
        onDelete();
        return false;
      },
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                color: todo.isDone ? color : Colors.grey.shade400,
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
            color: todo.isDone ? Colors.grey : null,
            fontWeight: todo.isDone ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                todo.categoryLabel,
                style: TextStyle(fontSize: 10, color: color),
              ),
            ),
            if (todo.dueDate != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.event, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 2),
              Text(
                '${todo.dueDate!.month}/${todo.dueDate!.day}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
            if (todo.isOverdue) ...[
              const SizedBox(width: 8),
              const Icon(Icons.error, size: 12, color: Colors.red),
              const Text(' 已过期',
                  style: TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 优先级指示
            ...List.generate(
              todo.priority,
              (i) => Icon(Icons.star, size: 12, color: Colors.orange.shade300),
            ),
            const SizedBox(width: 4),
            // 星标
            if (todo.isStarred)
              const Icon(Icons.star, size: 16, color: Colors.amber),
          ],
        ),
      ),
    );
  }
}
