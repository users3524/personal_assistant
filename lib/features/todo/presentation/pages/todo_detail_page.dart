/// 待办详情页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/todo_entity.dart';
import '../providers/todo_providers.dart';

class TodoDetailPage extends ConsumerStatefulWidget {
  final int todoId;

  const TodoDetailPage({super.key, required this.todoId});

  @override
  ConsumerState<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends ConsumerState<TodoDetailPage> {
  Future<TodoEntity?> _loadTodo() async {
    final repo = ref.read(todoRepositoryProvider).requireValue;
    return repo.getById(widget.todoId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TodoEntity?>(
      future: _loadTodo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final todo = snapshot.data;
        if (todo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('待办详情')),
            body: const Center(child: Text('待办不存在')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(todo.title),
            actions: [
              IconButton(
                icon: Icon(
                  todo.isStarred ? Icons.star : Icons.star_border,
                  color: todo.isStarred ? Colors.amber : null,
                ),
                onPressed: () async {
                  await ref
                      .read(todoListProvider.notifier)
                      .toggleStar(todo.id!);
                  setState(() {});
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleAction(context, todo, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 状态卡片
                _buildStatusCard(todo),
                const SizedBox(height: 16),

                // 描述
                if (todo.description != null &&
                    todo.description!.isNotEmpty) ...[
                  Text('描述',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(todo.description!,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                ],

                // 详细信息
                _buildInfoSection(todo),
                const SizedBox(height: 24),

                // 操作按钮
                _buildActionButtons(todo),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(TodoEntity todo) {
    final color = _getStatusColor(todo);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _getStatusIcon(todo),
              color: color,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.statusLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (todo.isOverdue)
                    const Text(
                      '已过期',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            // 优先级星星
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < todo.priority ? Icons.star : Icons.star_border,
                  size: 16,
                  color: index < todo.priority ? Colors.orange : Colors.grey,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(TodoEntity todo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.category,
              '分类',
              todo.categoryLabel,
              todo.category == TodoCategory.life ? Colors.green : Colors.blue,
            ),
            const Divider(),
            _buildInfoRow(
              Icons.access_time,
              '创建时间',
              _formatDate(todo.createdAt),
              null,
            ),
            if (todo.dueDate != null) ...[
              const Divider(),
              _buildInfoRow(
                Icons.event,
                '截止日期',
                _formatDate(todo.dueDate!),
                todo.isOverdue ? Colors.red : null,
              ),
            ],
            if (todo.completedAt != null) ...[
              const Divider(),
              _buildInfoRow(
                Icons.check_circle,
                '完成时间',
                _formatDate(todo.completedAt!),
                Colors.green,
              ),
            ],
            if (todo.actualMinutes != null) ...[
              const Divider(),
              _buildInfoRow(
                Icons.timer,
                '实际耗时',
                '${todo.actualMinutes} 分钟',
                null,
              ),
            ],
            if (todo.delayCount > 0) ...[
              const Divider(),
              _buildInfoRow(
                Icons.warning,
                '延期次数',
                '${todo.delayCount} 次',
                Colors.orange,
              ),
            ],
            if (todo.tags.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: todo.tags.map((tag) {
                    return Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Text('$label：',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(TodoEntity todo) {
    if (todo.isDone || todo.status == TodoStatus.cancelled) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (!todo.isInProgress)
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                await ref
                    .read(todoListProvider.notifier)
                    .startTodo(todo.id!);
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始执行'),
            ),
          ),
        if (todo.isInProgress) ...[
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                await ref
                    .read(todoListProvider.notifier)
                    .completeTodo(todo.id!);
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.check),
              label: const Text('标记完成'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref
                    .read(todoListProvider.notifier)
                    .cancelTodo(todo.id!);
                if (mounted) {
                  context.pop();
                }
              },
              icon: const Icon(Icons.close),
              label: const Text('放弃'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleAction(BuildContext context, TodoEntity todo, String action) {
    switch (action) {
      case 'edit':
        context.push('/todos/${todo.id}/edit');
        break;
      case 'delete':
        _confirmDelete(context, todo);
        break;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TodoEntity todo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${todo.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(todoListProvider.notifier).deleteTodo(todo.id!);
      if (mounted) context.pop();
    }
  }

  Color _getStatusColor(TodoEntity todo) {
    if (todo.isDone) return Colors.green;
    if (todo.isOverdue) return Colors.red;
    if (todo.isInProgress) return Colors.blue;
    return Colors.grey;
  }

  IconData _getStatusIcon(TodoEntity todo) {
    if (todo.isDone) return Icons.check_circle;
    if (todo.isOverdue) return Icons.error;
    if (todo.isInProgress) return Icons.play_circle;
    return Icons.radio_button_unchecked;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
