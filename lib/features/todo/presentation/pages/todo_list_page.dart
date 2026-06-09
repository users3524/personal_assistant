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

  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  bool _overdueCheckDone = false;

  @override
  Widget build(BuildContext context) {
    final todoListAsync = ref.watch(todoListProvider);
    // 每天首次加载时顺延过期待办
    if (!_overdueCheckDone) {
      _overdueCheckDone = true;
      Future.microtask(() => _carryOverOverdueTodos());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings'),
        ),
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
            icon: const Icon(Icons.archive_outlined),
            tooltip: '归档',
            onPressed: () => _showArchivePage(context),
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
          // 月视图底部历史入口
          if (_viewMode == CalendarView.month)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                onTap: () => _showHistoryView(context),
                child: Text('历史日/周报查看',
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
    return _MonthGrid(
      monthStart: _monthStart,
      selectedDate: _selectedDate,
      today: today,
      reviewDays: reviewDays,
      onDateSelected: (date) => setState(() => _selectedDate = date),
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
      key: Key('todo_${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除待办'),
            content: Text('将「${todo.title}」移入回收站？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        // 乐观更新：立即从本地状态移除，防 Dismissible 报错
        ref.read(todoListProvider.notifier).deleteTodoLocal(todo.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${todo.title}」已移入回收站')),
        );
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
                Text(' 逾期${_overdueDays(todo)}天', style: TextStyle(fontSize: 10, color: Colors.red.shade400)),
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

  void _showArchivePage(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ArchivePage(),
    ));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 获取过期待办（pending 且已过期）
  List<TodoEntity> _getOverdueTodos(List<TodoEntity> todos) {
    return todos.where((t) => t.isOverdue).toList();
  }

  /// 计算逾期天数
  int _overdueDays(TodoEntity todo) {
    if (!todo.isOverdue) return 0;
    final now = DateTime.now();
    if (todo.dueDate != null) {
      return now.difference(todo.dueDate!).inDays;
    }
    if (todo.startedAt != null) {
      final startDay = DateTime(todo.startedAt!.year, todo.startedAt!.month, todo.startedAt!.day);
      return now.difference(startDay).inDays;
    }
    return 0;
  }

  /// 将过期待办的 dueDate 顺延到今天（不改变 createdAt）
  void _carryOverOverdueTodos() async {
    try {
      final repo = await ref.read(todoRepositoryProvider.future);
      final allTodos = await repo.getAll();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      for (final t in allTodos) {
        if (t.status == TodoStatus.pending && t.isOverdue) {
          if (t.dueDate != null) {
            await repo.update(t.copyWith(
              dueDate: todayStart,
              updatedAt: today,
            ));
          } else if (t.startedAt != null) {
            // 无截止日期但开始时间已过期的，将开始时间顺延到今天
            await repo.update(t.copyWith(
              startedAt: todayStart,
              updatedAt: today,
            ));
          }
        }
      }
      ref.read(todoListProvider.notifier).refresh();
    } catch (_) {}
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
                    // 日报记录
                    allMonthlyReviews.when(
                      data: (reviews) => reviews.isEmpty
                          ? const Center(child: Text('暂无日报记录'))
                          : ListView.builder(
                              itemCount: reviews.length,
                              itemBuilder: (_, i) {
                                final r = reviews[i];
                                return ListTile(
                                  leading: const Icon(Icons.article_outlined),
                                  title: Text('${r.date.year}年${r.date.month}月${r.date.day}日'),
                                  subtitle: Text(r.summary.length > 40 ? '${r.summary.substring(0, 40)}…' : r.summary,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Text('能量 ${r.energyLevel} · 情绪 ${r.moodLevel}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    final dateStr = r.date.toIso8601String().split('T')[0];
                                    context.push('/review/daily/$dateStr');
                                  },
                                );
                              },
                            ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const Center(child: Text('加载失败')),
                    ),
                    // 周报记录
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
                                  subtitle: Text(r.overview.length > 30 ? '${r.overview.substring(0, 30)}…' : r.overview),
                                  trailing: Text(r.createdAt.toString().split('T')[0], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    context.push('/review/weekly/${r.id}');
                                  },
                                );
                              },
                            ),
                      loading: () => const Center(child: CircularProgressIndicator()),
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

/// 归档页面 — 按日期分组显示已完成/已取消的待办
class _ArchivePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoListAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('历史归档')),
      body: todoListAsync.when(
        data: (todos) {
          final archived = todos
              .where((t) => t.status == TodoStatus.done || t.status == TodoStatus.cancelled)
              .toList()
            ..sort((a, b) {
              final aDate = a.completedAt ?? a.cancelledAt ?? a.createdAt;
              final bDate = b.completedAt ?? b.cancelledAt ?? b.createdAt;
              return bDate.compareTo(aDate);
            });
          if (archived.isEmpty) {
            return const Center(child: Text('暂无已归档的待办', style: TextStyle(color: Colors.grey)));
          }
          // 按日期分组
          final groups = <String, List<TodoEntity>>{};
          for (final t in archived) {
            final key = (t.completedAt ?? t.cancelledAt ?? t.createdAt).toString().split('T')[0];
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
                    child: Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ),
                  ...entry.value.map((t) => ListTile(
                    dense: true,
                    leading: Icon(t.isDone ? Icons.check_circle : Icons.cancel, color: t.isDone ? Colors.green : Colors.red, size: 20),
                    title: Text(t.title, style: TextStyle(fontSize: 14, decoration: t.isDone ? TextDecoration.lineThrough : null)),
                    subtitle: Text(t.category, style: const TextStyle(fontSize: 11)),
                    onTap: () => context.push('/todos/${t.id}'),
                  )),
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

/// 月视图日历网格控件 — 独立 Widget 减少重建范围，提升性能
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
                  child: Text(d,
                      style: TextStyle(
                          fontSize: 12,
                          color: (d == '六' || d == '日') ? Colors.grey : null)),
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
                  final date = DateTime(monthStart.year, monthStart.month, dayNum);
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
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
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
                              color: isSelected ? Colors.white : (isWeekend ? Colors.grey : null),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
