/// 待办列表页 — 周/月视图。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/todo_entity.dart';
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

  bool _showArchived = false;

  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final todoListAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        centerTitle: true,
        actions: [
          // 视图切换
          TextButton.icon(
            icon: Icon(_viewMode == CalendarView.week
                ? Icons.calendar_view_month
                : Icons.calendar_view_week),
            label: Text(_viewMode == CalendarView.week ? '月' : '周'),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == CalendarView.week
                    ? CalendarView.month
                    : CalendarView.week;
              });
            },
          ),
          // 分类管理
          // 归档切换
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: '归档',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: Column(
        children: [
          // 日历头
          _buildCalendarHeader(),
          // 日历网格
          _buildCalendarGrid(),
          const Divider(height: 1),
          // 选中日期的待办
          Flexible(
            flex: 1,
            child: todoListAsync.when(
              data: (todos) {
                if (_showArchived) {
                  // —— 归档视图：显示所有已完成/已取消的待办 ——
                  final archived = todos
                      .where((t) =>
                          t.status == TodoStatus.done ||
                          t.status == TodoStatus.cancelled)
                      .toList()
                    ..sort((a, b) {
                      final aDate =
                          a.completedAt ?? a.cancelledAt ?? a.createdAt;
                      final bDate =
                          b.completedAt ?? b.cancelledAt ?? b.createdAt;
                      return bDate.compareTo(aDate);
                    });
                  if (archived.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.archive_outlined,
                              size: 60,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('没有已完成的待办',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 6),
                            Text('已归档',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                )),
                            const SizedBox(width: 8),
                            Text('${archived.length}项',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: _buildTodoList(archived)),
                    ],
                  );
                }
                // —— 普通视图：选中日期的待办 ——
                final dayTodos = _getTodosForDate(todos, _selectedDate);
                // 今天额外显示过期待办
                final isToday = _isSameDay(_selectedDate, DateTime.now());
                final overdueTodos = isToday ? _getOverdueTodos(todos) : <TodoEntity>[];

                if (dayTodos.isEmpty && overdueTodos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt,
                            size: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text('当天没有待办',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                // 合并过期待办和当日待办
                final allTodos = [...overdueTodos, ...dayTodos];
                return _buildTodoList(allTodos, isToday);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('加载失败: $err')),
            ),
          ),
          // 每日复盘卡片（仅在周视图显示）
          if (_viewMode == CalendarView.week) _DailyReviewCard(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/todos/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ===== 日历头 =====

  Widget _buildCalendarHeader() {
    final headerDate =
        _viewMode == CalendarView.week ? _weekStart : _monthStart;
    final monthNames = [
      '一月', '二月', '三月', '四月', '五月', '六月',
      '七月', '八月', '九月', '十月', '十一月', '十二月'
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
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  // ===== 日历网格 =====

  Widget _buildCalendarGrid() {
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    // 按月视图当前查看的月份加载日报，而非始终加载本月
    final targetMonth = _viewMode == CalendarView.month ? _monthStart.month : now.month;
    final targetYear = _viewMode == CalendarView.month ? _monthStart.year : now.year;
    final monthlyReviews = ref.watch(dailyListByYearMonthProvider(targetYear * 100 + targetMonth));
    final reviewDays = monthlyReviews.valueOrNull
        ?.map((r) => r.date.day)
        .toSet() ?? <int>{};

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
          // 星期标签
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
          // 日期行（一周7天）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final date = _weekStart.add(Duration(days: index));
              final isToday = _isSameDay(date, today);
              final isSelected = _isSameDay(date, _selectedDate);
              final isWeekend = index >= 5;
              final hasReview = reviewDays.contains(date.day);

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                  if (hasReview && !_isSameDay(date, DateTime.now())) {
                    _showReviewEntry(context, date);
                  }
                },
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
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1)
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
    final firstDay = DateTime(_monthStart.year, _monthStart.month, 1);
    final lastDay = DateTime(_monthStart.year, _monthStart.month + 1, 0);
    // DateTime.weekday: Mon=1 .. Sun=7, 转为 Mon=0 .. Sun=6
    final startWeekday = firstDay.weekday - 1;
    final daysInMonth = lastDay.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells + 6) ~/ 7;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // 星期标签
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 12,
                          color: (d == '六' || d == '日')
                              ? Colors.grey
                              : null)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // 日期网格 - 使用 Table 确保完全对齐
          Table(
            children: List.generate(rows, (weekIndex) {
              return TableRow(
                children: List.generate(7, (colIndex) {
                  final dayNum = weekIndex * 7 + colIndex - startWeekday + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox(height: 38);
                  }
                  final date = DateTime(
                      _monthStart.year, _monthStart.month, dayNum);
                  final isToday = _isSameDay(date, today);
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isWeekend = colIndex >= 5;
                  final hasReview = reviewDays.contains(dayNum);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isToday
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1)
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

  // ===== 待办列表 =====

  List<TodoEntity> _getTodosForDate(
      List<TodoEntity> todos, DateTime date) {
    return todos.where((t) {
      // 已完成/已取消的待办：按 completedAt / cancelledAt 归入完成当天的日期
      if (t.status == TodoStatus.done) {
        return t.completedAt != null && _isSameDay(t.completedAt!, date);
      }
      if (t.status == TodoStatus.cancelled) {
        return t.cancelledAt != null && _isSameDay(t.cancelledAt!, date);
      }
      // 活跃的待办（pending / inProgress）：按 createdAt 显示
      return _isSameDay(t.createdAt, date);
    }).toList()
      ..sort((a, b) {
        if (a.isStarred && !b.isStarred) return -1;
        if (!a.isStarred && b.isStarred) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Widget _buildTodoList(List<TodoEntity> todos, [bool showOverdue = false]) {
    return RefreshIndicator(
      onRefresh: () => ref.read(todoListProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return _buildTodoItem(todo);
        },
      ),
    );
  }

  Widget _buildTodoItem(TodoEntity todo) {
    return Dismissible(
      key: Key('todo_${todo.id}_${todo.status.name}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        if (_showArchived) {
          // 归档模式：直接删除（已完成的无需再取消）
          ref.read(todoListProvider.notifier).deleteTodo(todo.id!);
        } else {
          ref.read(todoListProvider.notifier).cancelTodo(todo.id!);
        }
        return true;
      },
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            if (todo.isDone) {
              // 已完成 → 恢复为待办
              ref.read(todoListProvider.notifier).reopenTodo(todo.id!);
            } else if (todo.status == TodoStatus.cancelled) {
              // 已取消 → 恢复为待办
              ref.read(todoListProvider.notifier).reopenTodo(todo.id!);
            } else {
              ref.read(todoListProvider.notifier).completeTodo(todo.id!);
            }
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
                color: Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                todo.category,
                style: const TextStyle(fontSize: 11, color: Colors.teal),
              ),
            ),
            if (todo.dueDate != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 12,
                  color: todo.isOverdue ? Colors.red : Colors.grey),
              const SizedBox(width: 2),
              Text(
                '${todo.dueDate!.month}/${todo.dueDate!.day}',
                style: TextStyle(fontSize: 11,
                    color: todo.isOverdue ? Colors.red : Colors.grey),
              ),
              if (todo.isOverdue)
                Text(' 已过期', style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
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
              onTap: () => context.push('/todos/${todo.id}'),
              child: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
        onTap: () => context.push('/todos/${todo.id}'),
      ),
    );
  }

  // ===== 导航 =====

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

  void _showReviewEntry(BuildContext context, DateTime date) async {
    final today = DateTime.now();
    final isPastOrToday = !date.isAfter(today);
    if (!isPastOrToday) return; // 未来日期不显示

    final normalized = DateTime(date.year, date.month, date.day);
    final review = await ref.read(dailyReviewProvider(normalized).future);
    if (review == null) return;

    final dateStr = normalized.toIso8601String().split('T')[0];
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${date.month}月${date.day}日 复盘',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(review.summary,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Row(children: [
              _miniBadge('能量 ${review.energyLevel}/5', Colors.orange),
              const SizedBox(width: 8),
              _miniBadge('情绪 ${review.moodLevel}/5', Colors.blue),
            ]),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('查看详情'),
                    onPressed: () { Navigator.pop(ctx); context.push('/review/daily/$dateStr'); },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('编辑'),
                    onPressed: () { Navigator.pop(ctx); context.push('/review/daily/edit/$dateStr'); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color.shade700)),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 获取过期待办（pending 且 dueDate 早于今天）
  List<TodoEntity> _getOverdueTodos(List<TodoEntity> todos) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return todos.where((t) => t.isOverdue && t.dueDate!.isBefore(todayStart)).toList();
  }
}

/// 每日复盘卡片 — 显示在待办列表底部
class _DailyReviewCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayReview = ref.watch(dailyReviewProvider(today));
    final hasReviewed = todayReview.valueOrNull != null;
    final review = todayReview.valueOrNull;
    final weekNumber = ref.watch(currentWeekNumberProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (hasReviewed) {
                // 已复盘 → 查看历史记录
                context.push('/review/daily/${today.toIso8601String().split('T')[0]}');
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
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasReviewed ? Icons.check_circle : Icons.auto_awesome,
                      color: hasReviewed ? Colors.green : Theme.of(context).colorScheme.primary,
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
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
        // 周报入口
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.assessment, size: 16),
                  label: Text('本周周报', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  onPressed: () => context.push('/review/weekly/$weekNumber'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
