/// 待办详情页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
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
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _buildTopBar(todo),
                const SizedBox(height: 14),
                Text(
                  todo.title,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppPill(
                      label: todo.category,
                      color: todo.category == '生活'
                          ? AppColors.green
                          : AppColors.blue,
                      icon: Icons.category_outlined,
                    ),
                    AppPill(
                      label: _priorityLabel(todo.priority),
                      color: todo.priority >= 4
                          ? AppColors.orange
                          : AppColors.primary,
                      icon: Icons.flag_outlined,
                    ),
                    if (todo.isStarred)
                      const AppPill(
                        label: '重点',
                        color: AppColors.gold,
                        icon: Icons.star,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildStatusCard(todo),
                const SizedBox(height: 18),

                _buildInfoSection(todo),
                const SizedBox(height: 18),

                if (todo.isParent) _buildSubtasksSection(todo),
                if (todo.isParent) const SizedBox(height: 18),

                const AppSectionTitle(title: '备注描述', padding: EdgeInsets.zero),
                const SizedBox(height: 8),
                AppSurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    todo.description == null || todo.description!.isEmpty
                        ? '暂无备注'
                        : todo.description!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color:
                          todo.description == null || todo.description!.isEmpty
                          ? AppColors.muted
                          : AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildActionButtons(todo),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(TodoEntity todo) {
    return Row(
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.primary,
          ),
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left),
          label: const Text('返回'),
        ),
        const Spacer(),
        IconButton(
          tooltip: todo.isStarred ? '取消重点' : '标为重点',
          icon: Icon(
            todo.isStarred ? Icons.star : Icons.star_border,
            color: todo.isStarred ? AppColors.gold : AppColors.muted,
          ),
          onPressed: () async {
            await ref.read(todoListProvider.notifier).toggleStar(todo.id!);
            setState(() {});
          },
        ),
        PopupMenuButton<String>(
          tooltip: '更多',
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) => _handleAction(context, todo, value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            if (todo.isParent)
              const PopupMenuItem(value: 'addSubtask', child: Text('添加子任务')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(TodoEntity todo) {
    final color = _getStatusColor(todo);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_getStatusIcon(todo), color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '状态',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todo.isOverdue
                          ? '${todo.statusLabel} · 已逾期'
                          : todo.statusLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < todo.priority ? Icons.star : Icons.star_border,
                    size: 16,
                    color: index < todo.priority
                        ? AppColors.gold
                        : AppColors.line,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildTimeRow(Icons.play_circle_outline, '开始时间', todo.startedAt),
          const SizedBox(height: 10),
          _buildTimeRow(
            Icons.event,
            '截止时间',
            todo.dueDate,
            color: todo.isOverdue ? AppColors.red : null,
          ),
          if (todo.completedAt != null) ...[
            const SizedBox(height: 10),
            _buildTimeRow(
              Icons.check_circle,
              '完成时间',
              todo.completedAt,
              color: AppColors.green,
            ),
          ],
        ],
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
        Icon(icon, size: 16, color: color ?? AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Text(
          date != null
              ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
              : '未设置',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color ?? (date == null ? AppColors.muted : AppColors.ink),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(TodoEntity todo) {
    final todoLists = ref.watch(todoListsProvider).valueOrNull ?? const [];
    final listName = _listNameOf(todo.listId, todoLists);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.category,
            '分类',
            todo.category,
            todo.category == '生活' ? AppColors.green : AppColors.blue,
          ),
          const Divider(),
          _buildInfoRow(
            Icons.folder_outlined,
            '清单',
            listName ?? '未归清单',
            listName == null ? AppColors.muted : AppColors.blue,
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
              AppColors.orange,
            ),
          ],
          if (todo.tags.isNotEmpty) ...[
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: todo.tags.map((tag) {
                  return AppPill(
                    label: tag,
                    color: AppColors.primary,
                    icon: Icons.sell_outlined,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
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
          Icon(icon, size: 18, color: color ?? AppColors.muted),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.ink,
              ),
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
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
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
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
    if (todo.isDone) return AppColors.green;
    if (todo.isOverdue) return AppColors.red;
    if (todo.isInProgress) return AppColors.blue;
    return AppColors.muted;
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

  String _priorityLabel(int priority) {
    if (priority >= 4) return '高优先级';
    if (priority == 3) return '中优先级';
    return '低优先级';
  }

  // ===== 子任务 =====

  Widget _buildSubtasksSection(TodoEntity todo) {
    final doneCount = todo.subtasks.where((s) => s.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          title: '子任务进度 ($doneCount/${todo.subtasks.length})',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        AppSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (todo.subtasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '暂无子任务，点击下方添加',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                )
              else
                ...todo.subtasks.map(
                  (s) => _SubtaskTile(
                    subtask: s,
                    onToggle: () {
                      if (s.isDone) {
                        ref.read(todoListProvider.notifier).reopenTodo(s.id!);
                      } else {
                        ref.read(todoListProvider.notifier).completeTodo(s.id!);
                      }
                      setState(() {});
                    },
                    onDelete: () async {
                      await ref
                          .read(todoListProvider.notifier)
                          .deleteTodo(s.id!);
                      setState(() {});
                    },
                  ),
                ),
              InkWell(
                onTap: () => _showAddSubtaskDialog(context, todo),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(
                    child: Text(
                      '+ 添加子任务',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

class _SubtaskTile extends StatelessWidget {
  const _SubtaskTile({
    required this.subtask,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoEntity subtask;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: subtask.isDone ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: subtask.isDone ? AppColors.primary : AppColors.line,
              width: 1.6,
            ),
          ),
          child: subtask.isDone
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : null,
        ),
      ),
      title: Text(
        subtask.title,
        style: TextStyle(
          fontSize: 14,
          decoration: subtask.isDone ? TextDecoration.lineThrough : null,
          color: subtask.isDone ? AppColors.muted : AppColors.ink,
          fontWeight: subtask.isDone ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
        onPressed: onDelete,
      ),
    );
  }
}
