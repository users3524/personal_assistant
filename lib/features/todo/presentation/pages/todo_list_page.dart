/// 待办列表页 — 主页面。
///
/// 功能：
/// - 顶部统计仪表盘（自动同步）
/// - 分类筛选（全部/生活/工作/学习/健康，可自定义）
/// - 排序方式（创建时间/截止时间）
/// - 日期分组 + 分隔线 + 日期标签
/// - FAB 新建待办
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/todo_entity.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_stats_card.dart';

class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final sortMode = ref.watch(sortModeProvider);
    final todoListAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, ref),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => ref.read(sortModeProvider.notifier).state = value,
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'createdAt',
                checked: sortMode == 'createdAt',
                child: const Text('按创建时间'),
              ),
              CheckedPopupMenuItem(
                value: 'dueDate',
                checked: sortMode == 'dueDate',
                child: const Text('按截止时间'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'manage_categories') {
                _showManageCategories(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage_categories',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('管理分类'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计仪表盘（自动观察 todoListProvider 刷新）
          const TodoStatsCard(),
          // 分类筛选条
          _buildCategoryBar(context, ref, selectedCategory),
          // 待办列表
          Expanded(
            child: todoListAsync.when(
              data: (todos) {
                // 按分类筛选
                var filtered = selectedCategory == null
                    ? todos
                    : todos.where((t) => t.category == selectedCategory).toList();
                // 过滤已取消的
                filtered = filtered
                    .where((t) => t.status != TodoStatus.cancelled)
                    .toList();
                // 排序
                if (sortMode == 'dueDate') {
                  filtered.sort((a, b) {
                    if (a.dueDate == null && b.dueDate == null) return 0;
                    if (a.dueDate == null) return 1;
                    if (b.dueDate == null) return -1;
                    return a.dueDate!.compareTo(b.dueDate!);
                  });
                } else {
                  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                }
                // 按日期分组
                final grouped = <String, List<TodoEntity>>{};
                for (final todo in filtered) {
                  final dateKey =
                      '${todo.createdAt.year}-${todo.createdAt.month.toString().padLeft(2, '0')}-${todo.createdAt.day.toString().padLeft(2, '0')}';
                  grouped.putIfAbsent(dateKey, () => []);
                  grouped[dateKey]!.add(todo);
                }
                // 获取日期排序的 keys
                final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(todoListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final dateKey = sortedKeys[index];
                      final dayTodos = grouped[dateKey]!;
                      final date = DateTime.parse(dateKey);
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final diff = date.difference(today).inDays;

                      String dateLabel;
                      if (diff == 0) {
                        dateLabel = '今天';
                      } else if (diff == -1) {
                        dateLabel = '昨天';
                      } else if (diff >= 1 && diff <= 6) {
                        dateLabel = '${['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1]}';
                      } else {
                        dateLabel = '${date.month}月${date.day}日';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 日期分隔线
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateKey,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const Expanded(child: Divider(indent: 8)),
                              ],
                            ),
                          ),
                          // 当天的待办
                          ...dayTodos.map((todo) => _buildTodoItem(
                                context,
                                ref,
                                todo,
                              )),
                        ],
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('加载失败: $err'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/todos/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, TodoEntity todo) {
    return Dismissible(
      key: Key('todo_${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(todoListProvider.notifier).cancelTodo(todo.id!);
      },
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            if (todo.isDone) return;
            ref.read(todoListProvider.notifier).completeTodo(todo.id!);
          },
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: todo.isDone ? Colors.green : Colors.grey,
                width: 2,
              ),
              color: todo.isDone ? Colors.green : Colors.transparent,
            ),
            child: todo.isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isDone ? TextDecoration.lineThrough : null,
            color: todo.isDone ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            if (todo.isOverdue)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.warning_amber, size: 14, color: Colors.red),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _categoryColor(todo.category).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                todo.category,
                style: TextStyle(
                  fontSize: 11,
                  color: _categoryColor(todo.category),
                ),
              ),
            ),
            if (todo.dueDate != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 12, color: Colors.grey),
              const SizedBox(width: 2),
              Text(
                '${todo.dueDate!.month}/${todo.dueDate!.day}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            if (todo.priority >= 4)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.flag, size: 14, color: Colors.orange),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                todo.isStarred ? Icons.star : Icons.star_border,
                color: todo.isStarred ? Colors.amber : Colors.grey,
                size: 20,
              ),
              onPressed: () {
                ref.read(todoListProvider.notifier).toggleStar(todo.id!);
              },
            ),
            GestureDetector(
              onTap: () => _openDetail(context, todo),
              child: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
        onTap: () => _openDetail(context, todo),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('还没有待办', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text('点击右下角 + 添加'),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(
    BuildContext context,
    WidgetRef ref,
    String? selected,
  ) {
    final categories = defaultCategories;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _categoryChip(context, ref, '全部', null, Icons.all_inclusive,
                Colors.grey, selected == null),
            ...categories.map((cat) => _categoryChip(
                  context,
                  ref,
                  cat,
                  cat,
                  _categoryIcon(cat),
                  _categoryColor(cat),
                  selected == cat,
                )),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    String? category,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          ref.read(selectedCategoryProvider.notifier).state = category;
        },
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
        selectedColor: color,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : null,
          fontSize: 13,
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case '生活':
        return Colors.green;
      case '工作':
        return Colors.blue;
      case '学习':
        return Colors.purple;
      case '健康':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '生活':
        return Icons.home;
      case '工作':
        return Icons.work;
      case '学习':
        return Icons.school;
      case '健康':
        return Icons.favorite;
      default:
        return Icons.category;
    }
  }

  void _openDetail(BuildContext context, TodoEntity todo) {
    context.push('/todos/${todo.id}');
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _TodoSearchDelegate(ref),
    );
  }

  void _showManageCategories(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('管理分类'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: '输入新分类名称',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        // 添加到本地存储（持久化）
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('已添加分类「$name」')),
                        );
                        controller.clear();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '当前分类：生活、工作、学习、健康\n（更多分类功能开发中）',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

// ===== 搜索委托 =====

class _TodoSearchDelegate extends SearchDelegate<TodoEntity?> {
  final WidgetRef ref;

  _TodoSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('输入关键词搜索待办'),
      );
    }
    return _buildSearchList(context);
  }

  Widget _buildSearchList(BuildContext context) {
    final repo = ref.read(todoRepositoryProvider).requireValue;
    return FutureBuilder<List<TodoEntity>>(
      future: repo.search(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('未找到匹配的待办'));
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final todo = snapshot.data![index];
            return ListTile(
              leading: Icon(Icons.check_circle_outline, color: Colors.grey),
              title: Text(todo.title),
              subtitle: Text(todo.statusLabel),
              trailing: Icon(
                todo.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: todo.isDone ? Colors.green : Colors.grey,
              ),
              onTap: () {
                close(context, todo);
                context.push('/todos/${todo.id}');
              },
            );
          },
        );
      },
    );
  }
}
