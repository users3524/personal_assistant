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
                  if (todo.isParent)
                    const PopupMenuItem(
                      value: 'addSubtask',
                      child: Text('添加子任务'),
                    ),
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
                // 状态卡片 + 时间摘要
                _buildStatusCard(todo),
                const SizedBox(height: 16),

                // 描述
                if (todo.description != null &&
                    todo.description!.isNotEmpty) ...[
                  Text('描述', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    todo.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],

                // 详细信息
                _buildInfoSection(todo),
                const SizedBox(height: 24),

                // 子任务列表
                if (todo.isParent) _buildSubtasksSection(todo),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getStatusIcon(todo), color: color, size: 40),
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
                          '已逾期',
                          style: TextStyle(color: Colors.red, fontSize: 12),
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
                      color: index < todo.priority
                          ? Colors.orange
                          : Colors.grey,
                    );
                  }),
                ),
              ],
            ),
            const Divider(height: 24),
            // 时间信息
            _buildTimeRow(Icons.play_circle_outline, '开始时间', todo.startedAt),
            const SizedBox(height: 6),
            _buildTimeRow(
              Icons.event,
              '截止时间',
              todo.dueDate,
              color: todo.isOverdue ? Colors.red : null,
            ),
            if (todo.completedAt != null) ...[
              const SizedBox(height: 6),
              _buildTimeRow(
                Icons.check_circle,
                '完成时间',
                todo.completedAt,
                color: Colors.green,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow(
    IconData icon,
    String label,
    DateTime? date, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label：',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          date != null
              ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
              : '未设置',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: color ?? (date == null ? Colors.grey : null),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(TodoEntity todo) {
    final todoLists = ref.watch(todoListsProvider).valueOrNull ?? const [];
    final listName = _listNameOf(todo.listId, todoLists);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.category,
              '分类',
              todo.category,
              todo.category == '生活' ? Colors.green : Colors.blue,
            ),
            const Divider(),
            _buildInfoRow(
              Icons.folder_outlined,
              '清单',
              listName ?? '未归清单',
              listName == null ? Colors.grey : Colors.indigo,
            ),
            const Divider(),
            _buildInfoRow(
              Icons.access_time,
              '创建时间',
              _formatDate(todo.createdAt),
              null,
            ),
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

  String? _listNameOf(int? listId, List<TodoListEntity> lists) {
    if (listId == null) return null;
    for (final list in lists) {
      if (list.id == listId) return list.name;
    }
    return null;
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color? color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey),
          const SizedBox(width: 12),
          Text('$label：', style: const TextStyle(color: Colors.grey)),
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
                await ref.read(todoListProvider.notifier).startTodo(todo.id!);
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
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(todoListProvider.notifier).cancelTodo(todo.id!);
                if (mounted) {
                  context.pop();
                }
              },
              icon: const Icon(Icons.close),
              label: const Text('放弃'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
      case 'addSubtask':
        _showAddSubtaskDialog(context, todo);
        break;
      case 'delete':
        _confirmDelete(context, todo);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, TodoEntity todo) async {
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
      if (!mounted) return;
      this.context.pop();
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

  // ===== 子任务 =====

  Widget _buildSubtasksSection(TodoEntity todo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('子任务', style: Theme.of(context).textTheme.titleMedium),
                if (todo.subtasks.isNotEmpty)
                  Text(
                    ' (${todo.subtasks.where((s) => s.isDone).length}/${todo.subtasks.length})',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade600),
                  ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加'),
                  onPressed: () => _showAddSubtaskDialog(context, todo),
                ),
              ],
            ),
            if (todo.subtasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '暂无子任务，点击上方添加',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              )
            else
              ...todo.subtasks.map(
                (s) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: GestureDetector(
                    onTap: () {
                      if (s.isDone) {
                        ref.read(todoListProvider.notifier).reopenTodo(s.id!);
                      } else {
                        ref.read(todoListProvider.notifier).completeTodo(s.id!);
                      }
                      setState(() {});
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.isDone ? Colors.teal : Colors.transparent,
                        border: Border.all(
                          color: s.isDone ? Colors.teal : Colors.grey,
                          width: 1.5,
                        ),
                      ),
                      child: s.isDone
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  title: Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 13,
                      decoration: s.isDone ? TextDecoration.lineThrough : null,
                      color: s.isDone ? Colors.grey : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red,
                    ),
                    onPressed: () async {
                      await ref
                          .read(todoListProvider.notifier)
                          .deleteTodo(s.id!);
                      setState(() {});
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddSubtaskDialog(BuildContext context, TodoEntity todo) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加子任务'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '子任务名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final now = DateTime.now();
              final subtask = TodoEntity(
                title: ctrl.text.trim(),
                category: todo.category,
                listId: todo.listId,
                priority: todo.priority,
                createdAt: now,
                updatedAt: now,
              );
              await ref
                  .read(todoListProvider.notifier)
                  .addSubtask(todo.id!, subtask);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}
