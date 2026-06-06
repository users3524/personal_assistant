/// 待办列表页 — 主页面。
///
/// 包含：
/// - 顶部统计仪表盘
/// - TabBar 切换（生活/工作）
/// - 待办列表（Slidable 操作）
/// - FAB 新建
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/todo_entity.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_list_view.dart';
import '../widgets/todo_stats_card.dart';

class TodoListPage extends ConsumerWidget {
  const TodoListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final todoListAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        actions: [
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, ref),
          ),
          // 视图切换（列表/看板/日历）
          PopupMenuButton<String>(
            icon: const Icon(Icons.view_module),
            onSelected: (value) => _switchView(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'list', child: Text('列表视图')),
              const PopupMenuItem(value: 'kanban', child: Text('看板视图')),
              const PopupMenuItem(value: 'calendar', child: Text('日历视图')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计仪表盘
          const TodoStatsCard(),
          // 分类 Tab
          _buildCategoryTabBar(context, ref, selectedCategory),
          // 待办列表
          Expanded(
            child: todoListAsync.when(
              data: (todos) {
                // 按当前分类筛选
                final filtered = todos
                    .where((t) => t.category == selectedCategory)
                    .where((t) => t.status != TodoStatus.cancelled)
                    .toList();
                return TodoListView(
                  todos: filtered,
                  onToggle: (todo) => _toggleComplete(ref, todo),
                  onDelete: (todo) => _deleteTodo(context, ref, todo),
                  onTap: (todo) => _openDetail(context, todo),
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

  Widget _buildCategoryTabBar(
    BuildContext context,
    WidgetRef ref,
    TodoCategory selected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildCategoryChip(
            context,
            label: '生活',
            icon: Icons.home,
            color: Colors.green,
            isSelected: selected == TodoCategory.life,
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state =
                    TodoCategory.life,
          ),
          const SizedBox(width: 12),
          _buildCategoryChip(
            context,
            label: '工作',
            icon: Icons.work,
            color: Colors.blue,
            isSelected: selected == TodoCategory.work,
            onTap: () =>
                ref.read(selectedCategoryProvider.notifier).state =
                    TodoCategory.work,
          ),
          const Spacer(),
          // 状态筛选
          _buildStatusFilterDropdown(context, ref),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: color, width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterDropdown(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink(); // TODO: 状态筛选
  }

  Future<void> _toggleComplete(WidgetRef ref, TodoEntity todo) async {
    if (todo.isDone) return;
    await ref.read(todoListProvider.notifier).completeTodo(todo.id!);
  }

  Future<void> _deleteTodo(
    BuildContext context,
    WidgetRef ref,
    TodoEntity todo,
  ) async {
    await ref.read(todoListProvider.notifier).cancelTodo(todo.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${todo.title}」已删除'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              // TODO: undo
            },
          ),
        ),
      );
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

  void _switchView(BuildContext context, String view) {
    // TODO: 切换视图
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$view 视图即将上线')),
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
              leading: Icon(
                todo.category == TodoCategory.life
                    ? Icons.home
                    : Icons.work,
                color: todo.category == TodoCategory.life
                    ? Colors.green
                    : Colors.blue,
              ),
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
