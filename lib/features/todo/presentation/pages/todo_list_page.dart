/// 待办列表页 — 周/月视图。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/todo_entity.dart';
import '../providers/todo_categories_provider.dart';
import '../providers/todo_providers.dart';
import '../../../ai_assistant/presentation/providers/review_providers.dart';

// ===== 视图模式 =====
enum CalendarView { week, month }

// ===== 页面 =====

class TodoListPage extends ConsumerStatefulWidget {
  const TodoListPage({super.key});

  @override
  ConsumerState<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends ConsumerState<TodoListPage> {
  DateTime _selectedDate = DateTime.now();
  DateTime _weekStart = _getWeekStart(DateTime.now());
  DateTime _monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  CalendarView _viewMode = CalendarView.week;

  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final todoListAsync = ref.watch(todoListProvider);
    final todoLists =
        ref.watch(todoListsProvider).valueOrNull ?? const <TodoListEntity>[];
    final selectedListFilter = ref.watch(selectedTodoListFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings'),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: Icon(
              _viewMode == CalendarView.week
                  ? Icons.calendar_view_month
                  : Icons.calendar_view_week,
            ),
            label: Text(_viewMode == CalendarView.week ? '月' : '周'),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == CalendarView.week
                    ? CalendarView.month
                    : CalendarView.week;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: '归档',
            onPressed: () => _showArchivePage(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendarHeader(),
          _buildCalendarGrid(),
          const Divider(height: 1),
          _buildTodoListFilterBar(todoListAsync.valueOrNull ?? const []),
          // 统计仪表盘（仅周视图）
          if (_viewMode == CalendarView.week) const TodoStatsCard(),
          // 选中日期的待办列表
          Flexible(
            flex: 1,
            child: todoListAsync.when(
              data: (todos) {
                // 使用 displayDate 和 shouldShowInToday 过滤
                final isToday = _isSameDay(_selectedDate, DateTime.now());
                final dayTodos = isToday
                    ? todos.where((t) => t.shouldShowInToday).toList()
                    : todos
                          .where(
                            (t) => _isSameDay(t.displayDate, _selectedDate),
                          )
                          .toList();
                final filteredTodos = _filterByTodoList(
                  dayTodos,
                  selectedListFilter,
                );

                if (filteredTodos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 60,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _emptyMessageForFilter(selectedListFilter, todoLists),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return TodoListView(
                  todos: filteredTodos,
                  listNames: {
                    for (final list in todoLists)
                      if (list.id != null) list.id!: list.name,
                  },
                  onToggle: (todo) {
                    if (todo.isDone || todo.status == TodoStatus.cancelled) {
                      ref.read(todoListProvider.notifier).reopenTodo(todo.id!);
                    } else {
                      ref
                          .read(todoListProvider.notifier)
                          .completeTodo(todo.id!);
                    }
                  },
                  onDelete: (todo) {
                    ref
                        .read(todoListProvider.notifier)
                        .deleteTodoLocal(todo.id!);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('「${todo.title}」已移入回收站')),
                    );
                  },
                  onTap: (todo) => context.push('/todos/${todo.id}'),
                  onRefresh: () =>
                      ref.read(todoListProvider.notifier).refresh(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('加载失败: $err')),
            ),
          ),
          // 每日复盘卡片（仅在周视图显示）
          if (_viewMode == CalendarView.week) _DailyReviewCard(),
          if (_viewMode == CalendarView.month)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: () => _showHistoryView(context),
                child: Text(
                  '历史日/周报查看',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewTodoForm(todoLists, selectedListFilter),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<TodoEntity> _filterByTodoList(
    List<TodoEntity> todos,
    int? selectedListId,
  ) {
    if (selectedListId == null) return todos;
    if (selectedListId == unlistedTodoListFilter) {
      return todos.where((todo) => todo.listId == null).toList();
    }
    return todos.where((todo) => todo.listId == selectedListId).toList();
  }

  String _emptyMessageForFilter(
    int? selectedListId,
    List<TodoListEntity> lists,
  ) {
    if (selectedListId == null) return '当天没有待办';
    if (selectedListId == unlistedTodoListFilter) return '未归清单里没有当天待办';
    final selectedList = lists.where((list) => list.id == selectedListId);
    final name = selectedList.isEmpty ? '这个清单' : selectedList.first.name;
    return '「$name」没有当天待办';
  }

  void _openNewTodoForm(List<TodoListEntity> lists, int? selectedListId) {
    final selectedList =
        selectedListId == null || selectedListId == unlistedTodoListFilter
        ? null
        : _findTodoList(lists, selectedListId);
    final queryParameters = selectedList == null
        ? null
        : {
            'listId': selectedList.id.toString(),
            'category': selectedList.category,
          };
    context.push(
      Uri(path: '/todos/new', queryParameters: queryParameters).toString(),
    );
  }

  TodoListEntity? _findTodoList(List<TodoListEntity> lists, int id) {
    for (final list in lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  Widget _buildTodoListFilterBar(List<TodoEntity> todos) {
    final listsAsync = ref.watch(todoListsProvider);
    final selectedListId = ref.watch(selectedTodoListFilterProvider);

    return listsAsync.when(
      data: (lists) {
        final parentTodos = todos.where((todo) => todo.isParent).toList();
        final totalCount = parentTodos.length;
        final unlistedCount = parentTodos
            .where((todo) => todo.listId == null)
            .length;
        final countsByListId = <int, int>{};
        for (final todo in parentTodos) {
          final listId = todo.listId;
          if (listId == null) continue;
          countsByListId[listId] = (countsByListId[listId] ?? 0) + 1;
        }

        return SizedBox(
          height: 54,
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    _buildFilterChip(
                      label: '全部',
                      icon: Icons.inbox_outlined,
                      count: totalCount,
                      selected: selectedListId == null,
                      onTap: () =>
                          ref
                                  .read(selectedTodoListFilterProvider.notifier)
                                  .state =
                              null,
                    ),
                    _buildFilterChip(
                      label: '未归清单',
                      icon: Icons.folder_off_outlined,
                      count: unlistedCount,
                      selected: selectedListId == unlistedTodoListFilter,
                      onTap: () =>
                          ref
                                  .read(selectedTodoListFilterProvider.notifier)
                                  .state =
                              unlistedTodoListFilter,
                    ),
                    ...lists.map(
                      (list) => _buildFilterChip(
                        label: list.name,
                        icon: Icons.folder_outlined,
                        count: countsByListId[list.id] ?? 0,
                        selected: selectedListId == list.id,
                        onTap: () =>
                            ref
                                .read(selectedTodoListFilterProvider.notifier)
                                .state = list
                                .id,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '管理清单',
                icon: const Icon(Icons.tune),
                onPressed: () => _showTodoListManager(context),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 54,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (err, _) =>
          SizedBox(height: 54, child: Center(child: Text('清单加载失败: $err'))),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        showCheckmark: false,
        avatar: Icon(icon, size: 16),
        label: Text('$label $count'),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }

  void _showTodoListManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _TodoListManagerSheet(),
    );
  }

  // ===== 日历头 =====

  Widget _buildCalendarHeader() {
    final headerDate = _viewMode == CalendarView.week
        ? _weekStart
        : _monthStart;
    final monthNames = [
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previous,
          ),
          Text(
            _viewMode == CalendarView.week
                ? '${headerDate.month}月${headerDate.day}日 - ${(headerDate.add(const Duration(days: 6))).month}月${(headerDate.add(const Duration(days: 6))).day}日'
                : '${headerDate.year}年${monthNames[headerDate.month - 1]}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _next),
        ],
      ),
    );
  }

  // ===== 日历网格 =====

  Widget _buildCalendarGrid() {
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final targetMonth = _viewMode == CalendarView.month
        ? _monthStart.month
        : now.month;
    final targetYear = _viewMode == CalendarView.month
        ? _monthStart.year
        : now.year;
    final monthlyReviews = ref.watch(
      dailyListByYearMonthProvider(targetYear * 100 + targetMonth),
    );
    final reviewDays =
        monthlyReviews.valueOrNull?.map((r) => r.date.day).toSet() ?? <int>{};

    if (_viewMode == CalendarView.week) {
      return _buildWeekGrid(today, reviewDays);
    } else {
      return _buildMonthGrid(today, reviewDays);
    }
  }

  Widget _buildWeekGrid(DateTime today, Set<int> reviewDays) {
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: weekDays.map((day) {
              final isWeekend = day == '六' || day == '日';
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      color: isWeekend ? Colors.grey : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final date = _weekStart.add(Duration(days: index));
              final isToday = _isSameDay(date, today);
              final isSelected = _isSameDay(date, _selectedDate);
              final isWeekend = index >= 5;
              final hasReview = reviewDays.contains(date.day);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  width: 38,
                  height: 42,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : isToday
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1)
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday ? FontWeight.bold : null,
                            color: isSelected
                                ? Colors.white
                                : isWeekend
                                ? Colors.grey
                                : null,
                          ),
                        ),
                      ),
                      if (hasReview)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime today, Set<int> reviewDays) {
    return _MonthGrid(
      monthStart: _monthStart,
      selectedDate: _selectedDate,
      today: today,
      reviewDays: reviewDays,
      onDateSelected: (date) => setState(() => _selectedDate = date),
    );
  }

  void _previous() {
    setState(() {
      if (_viewMode == CalendarView.week) {
        _weekStart = _weekStart.subtract(const Duration(days: 7));
      } else {
        _monthStart = DateTime(_monthStart.year, _monthStart.month - 1, 1);
      }
    });
  }

  void _next() {
    setState(() {
      if (_viewMode == CalendarView.week) {
        _weekStart = _weekStart.add(const Duration(days: 7));
      } else {
        _monthStart = DateTime(_monthStart.year, _monthStart.month + 1, 1);
      }
    });
  }

  void _showHistoryView(BuildContext context) {
    final weeklyReports = ref.watch(weeklyListByYearProvider);
    final allMonthlyReviews = ref.watch(allDailyReviewsProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: '日报记录'),
                  Tab(text: '周报记录'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    allMonthlyReviews.when(
                      data: (reviews) => reviews.isEmpty
                          ? const Center(child: Text('暂无日报记录'))
                          : ListView.builder(
                              itemCount: reviews.length,
                              itemBuilder: (_, i) {
                                final r = reviews[i];
                                return ListTile(
                                  leading: const Icon(Icons.article_outlined),
                                  title: Text(
                                    '${r.date.year}年${r.date.month}月${r.date.day}日',
                                  ),
                                  subtitle: Text(
                                    r.summary.length > 40
                                        ? '${r.summary.substring(0, 40)}…'
                                        : r.summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    '能量 ${r.energyLevel} · 情绪 ${r.moodLevel}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    final dateStr = r.date
                                        .toIso8601String()
                                        .split('T')[0];
                                    context.push('/review/daily/$dateStr');
                                  },
                                );
                              },
                            ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Center(child: Text('加载失败')),
                    ),
                    weeklyReports.when(
                      data: (reports) => reports.isEmpty
                          ? const Center(child: Text('暂无周报记录'))
                          : ListView.builder(
                              itemCount: reports.length,
                              itemBuilder: (_, i) {
                                final r = reports[i];
                                return ListTile(
                                  leading: const Icon(Icons.article),
                                  title: Text('第${r.weekNumber}周'),
                                  subtitle: Text(
                                    r.overview.length > 30
                                        ? '${r.overview.substring(0, 30)}…'
                                        : r.overview,
                                  ),
                                  trailing: Text(
                                    r.createdAt.toString().split('T')[0],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.push(
                                      RouteNames.weeklyReportDetailPath(
                                        r.weekNumber,
                                        year: r.year,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Center(child: Text('加载失败')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArchivePage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ArchivePage()),
    );
  }
}

/// 待办列表视图 — 支持双向滑动（左滑删除，右滑切换完成状态）。
class TodoListView extends StatelessWidget {
  final List<TodoEntity> todos;
  final Map<int, String> listNames;
  final Function(TodoEntity) onToggle;
  final Function(TodoEntity) onDelete;
  final Function(TodoEntity) onTap;
  final Future<void> Function()? onRefresh;

  const TodoListView({
    super.key,
    required this.todos,
    this.listNames = const {},
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coffee, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '享受当下的清闲',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 展平树形结构：父任务 + 缩进的子任务
    final pending = <TodoEntity>[];
    final done = <TodoEntity>[];
    for (final t in todos.where((t) => t.isParent && t.isActive)) {
      pending.add(t);
      pending.addAll(t.subtasks.where((s) => s.isActive));
    }
    for (final t in todos.where((t) => t.isParent && !t.isActive)) {
      done.add(t);
      done.addAll(t.subtasks.where((s) => !s.isActive));
    }
    pending.sort((a, b) => b.priority.compareTo(a.priority));
    done.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final combined = [...pending, ...done];

    return RefreshIndicator(
      onRefresh: onRefresh ?? () => Future.value(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemCount: combined.length + (done.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == pending.length && done.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '已完成 (${done.length})',
                style: TextStyle(
                  color: Colors.grey.shade500,
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
            listName: todo.listId == null ? null : listNames[todo.listId],
            onToggle: () => onToggle(todo),
            onDelete: () => onDelete(todo),
            onTap: () => onTap(todo),
          );
        },
      ),
    );
  }
}

class _TodoListTile extends StatelessWidget {
  final TodoEntity todo;
  final String? listName;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _TodoListTile({
    required this.todo,
    required this.listName,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = todo.category == '工作'
        ? Colors.blue
        : todo.category == '生活'
        ? Colors.green
        : Colors.teal;

    return Dismissible(
      key: ValueKey('todo_list_item_${todo.id}'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: todo.isDone ? Colors.orange : Colors.green,
        child: Icon(
          todo.isDone ? Icons.undo : Icons.check,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.startToEnd) {
          onToggle();
          return false;
        }
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) onDelete();
      },
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.only(
          left: todo.isSubtask ? 48 : 16,
          right: 16,
          top: 2,
          bottom: 2,
        ),
        leading: todo.isSubtask
            ? const Icon(
                Icons.subdirectory_arrow_right,
                size: 18,
                color: Colors.grey,
              )
            : GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggle();
                },
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
            color: todo.isDone ? Colors.grey.shade400 : Colors.black87,
            fontWeight: todo.isDone ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _TodoMetaChip(label: todo.category, color: color),
            if (listName != null)
              _TodoMetaChip(
                label: listName!,
                color: Colors.indigo,
                icon: Icons.folder_outlined,
              ),
            if (todo.isParent && todo.subtasks.isNotEmpty)
              _TodoMetaChip(
                label:
                    '${todo.subtasks.where((s) => s.isDone).length}/${todo.subtasks.length}',
                color: Colors.teal,
                icon: Icons.account_tree_outlined,
              ),
            if (todo.isOverdue && !todo.isDone)
              const _TodoMetaChip(
                label: '逾期',
                color: Colors.red,
                icon: Icons.warning_amber,
                isStrong: true,
              )
            else if (todo.dueDate != null && !todo.isDone)
              _TodoMetaChip(
                label: '${todo.dueDate!.month}/${todo.dueDate!.day}',
                color: Colors.grey,
                icon: Icons.event,
              ),
          ],
        ),
        trailing: todo.isDone
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (todo.priority > 3)
                    Icon(
                      Icons.local_fire_department,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                  if (todo.isStarred)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.star, size: 16, color: Colors.amber),
                    ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isStrong ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoListManagerSheet extends ConsumerWidget {
  const _TodoListManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(todoListsProvider);
    final todos = ref.watch(todoListProvider).valueOrNull ?? const [];
    final countsByListId = <int, int>{};
    for (final todo in todos.where((todo) => todo.isParent)) {
      final listId = todo.listId;
      if (listId == null) continue;
      countsByListId[listId] = (countsByListId[listId] ?? 0) + 1;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '清单管理',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '新建清单',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () => _showListDialog(context, ref),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: listsAsync.when(
                  data: (lists) {
                    if (lists.isEmpty) {
                      return const Center(
                        child: Text(
                          '还没有清单',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: lists.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final list = lists[index];
                        final count = countsByListId[list.id] ?? 0;
                        return ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(list.name),
                          subtitle: Text('${list.category} · $count 个待办'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '编辑',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _showListDialog(context, ref, list: list),
                              ),
                              IconButton(
                                tooltip: '删除',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _confirmDelete(context, ref, list, count),
                              ),
                            ],
                          ),
                          onTap: () {
                            ref
                                .read(selectedTodoListFilterProvider.notifier)
                                .state = list
                                .id;
                            Navigator.pop(context);
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('加载失败: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showListDialog(
    BuildContext context,
    WidgetRef ref, {
    TodoListEntity? list,
  }) async {
    final nameController = TextEditingController(text: list?.name ?? '');
    final categories =
        ref.read(todoCategoriesProvider).valueOrNull ?? ['生活', '工作'];
    var selectedCategory = list?.category ?? categories.first;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(list == null ? '新建清单' : '编辑清单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: '清单名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: '所属分类',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: categories
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCategory = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final now = DateTime.now();
                await ref
                    .read(todoListsProvider.notifier)
                    .saveList(
                      TodoListEntity(
                        id: list?.id,
                        name: name,
                        category: selectedCategory,
                        createdAt: list?.createdAt ?? now,
                      ),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TodoListEntity list,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除清单'),
        content: Text('删除「${list.name}」后，$count 个待办会保留并移到未归清单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(todoListsProvider.notifier).deleteList(list.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已删除「${list.name}」')));
      }
    }
  }
}

/// 待办统计仪表盘卡片。
class TodoStatsCard extends ConsumerWidget {
  const TodoStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayCompleted =
        ref.watch(todayCompletedCountProvider).valueOrNull ?? 0;
    final todayTotal = ref.watch(todayTotalCountProvider).valueOrNull ?? 0;
    final weeklyRate =
        ref.watch(weeklyCompletionRateProvider).valueOrNull ?? 0.0;
    final delayRate = ref.watch(delayRateProvider).valueOrNull ?? 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              context,
              icon: Icons.task_alt,
              label: '今日完成',
              value: '$todayCompleted / $todayTotal',
              color: todayCompleted == todayTotal && todayTotal > 0
                  ? Colors.green
                  : Colors.blue,
            ),
            _buildDivider(),
            _buildStatItem(
              context,
              icon: Icons.trending_up,
              label: '本周达成',
              value: '${(weeklyRate * 100).toInt()}%',
              color: weeklyRate > 0.8 ? Colors.green : Colors.orange,
            ),
            _buildDivider(),
            _buildStatItem(
              context,
              icon: Icons.timer_off_outlined,
              label: '历史拖延',
              value: '${(delayRate * 100).toInt()}%',
              color: delayRate > 0.3
                  ? Colors.red.shade400
                  : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(width: 1, height: 32, color: Colors.grey.shade200);
}

// ===== 每日复盘卡片 =====

class _DailyReviewCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayReview = ref.watch(dailyReviewProvider(today));
    final hasReviewed = todayReview.valueOrNull != null;
    final review = todayReview.valueOrNull;
    final isoWeek = ref.watch(currentIsoWeekProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (hasReviewed) {
                context.push(
                  '/review/daily/${today.toIso8601String().split('T')[0]}',
                );
              } else {
                context.push('/review/daily/new');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasReviewed
                          ? Colors.green.withValues(alpha: 0.1)
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasReviewed ? Icons.check_circle : Icons.auto_awesome,
                      color: hasReviewed
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasReviewed ? '今日已复盘 ✓' : '每日复盘',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: hasReviewed ? Colors.green : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasReviewed
                              ? (review!.summary.length > 25
                                    ? '${review.summary.substring(0, 25)}…'
                                    : review.summary)
                              : '记录今天的感受和收获',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.assessment, size: 16),
                  label: Text(
                    '本周周报',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  onPressed: () => context.push(
                    RouteNames.weeklyReportDetailPath(
                      isoWeek.weekNumber,
                      year: isoWeek.year,
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
}

// ===== 归档页面 =====

class _ArchivePage extends ConsumerWidget {
  const _ArchivePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoListAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('历史归档')),
      body: todoListAsync.when(
        data: (todos) {
          final archived =
              todos
                  .where(
                    (t) =>
                        t.status == TodoStatus.done ||
                        t.status == TodoStatus.cancelled,
                  )
                  .toList()
                ..sort((a, b) {
                  final aDate = a.completedAt ?? a.cancelledAt ?? a.createdAt;
                  final bDate = b.completedAt ?? b.cancelledAt ?? b.createdAt;
                  return bDate.compareTo(aDate);
                });
          if (archived.isEmpty) {
            return const Center(
              child: Text('暂无已归档的待办', style: TextStyle(color: Colors.grey)),
            );
          }
          final groups = <String, List<TodoEntity>>{};
          for (final t in archived) {
            final key = (t.completedAt ?? t.cancelledAt ?? t.createdAt)
                .toString()
                .split('T')[0];
            groups.putIfAbsent(key, () => []);
            groups[key]!.add(t);
          }
          return ListView(
            children: groups.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                    (t) => ListTile(
                      dense: true,
                      leading: Icon(
                        t.isDone ? Icons.check_circle : Icons.cancel,
                        color: t.isDone ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      title: Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 14,
                          decoration: t.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        t.category,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => context.push('/todos/${t.id}'),
                    ),
                  ),
                  const Divider(indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
  }
}

// ===== 月视图日历网格 =====

class _MonthGrid extends StatelessWidget {
  final DateTime monthStart;
  final DateTime selectedDate;
  final DateTime today;
  final Set<int> reviewDays;
  final ValueChanged<DateTime> onDateSelected;

  const _MonthGrid({
    required this.monthStart,
    required this.selectedDate,
    required this.today,
    required this.reviewDays,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(monthStart.year, monthStart.month, 1);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final daysInMonth = lastDay.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells + 6) ~/ 7;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      color: (d == '六' || d == '日') ? Colors.grey : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Table(
            children: List.generate(rows, (weekIndex) {
              return TableRow(
                children: List.generate(7, (colIndex) {
                  final dayNum = weekIndex * 7 + colIndex - startWeekday + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox(height: 38);
                  }
                  final date = DateTime(
                    monthStart.year,
                    monthStart.month,
                    dayNum,
                  );
                  final isToday = _isSameDay(date, today);
                  final isSelected = _isSameDay(date, selectedDate);
                  final isWeekend = colIndex >= 5;
                  final hasReview = reviewDays.contains(dayNum);

                  return GestureDetector(
                    onTap: () => onDateSelected(date),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isToday
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday ? FontWeight.bold : null,
                              color: isSelected
                                  ? Colors.white
                                  : (isWeekend ? Colors.grey : null),
                            ),
                          ),
                          if (hasReview)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
