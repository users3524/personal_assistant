/// 待办列表页 — 周/月视图。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/todo_entity.dart';
import '../providers/todo_providers.dart';
import '../providers/todo_categories_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final todoListAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办清单'),
        centerTitle: true,
        actions: [
          // 视图切换
          IconButton(
            icon: Icon(_viewMode == CalendarView.week
                ? Icons.calendar_view_month
                : Icons.calendar_view_week),
            tooltip:
                _viewMode == CalendarView.week ? '月视图' : '周视图',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == CalendarView.week
                    ? CalendarView.month
                    : CalendarView.week;
              });
            },
          ),
          // 分类管理
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: '管理分类',
            onPressed: () => _showCategoryManager(context),
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
          Expanded(
            child: todoListAsync.when(
              data: (todos) {
                final dayTodos = _getTodosForDate(todos, _selectedDate);
                if (dayTodos.isEmpty) {
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
                return _buildTodoList(dayTodos);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('加载失败: $err')),
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

    if (_viewMode == CalendarView.week) {
      return _buildWeekGrid(today);
    } else {
      return _buildMonthGrid(today);
    }
  }

  Widget _buildWeekGrid(DateTime today) {
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

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  width: 38,
                  height: 38,
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
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime today) {
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

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      height: 38,
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
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.bold : null,
                          color: isSelected
                              ? Colors.white
                              : (isWeekend ? Colors.grey : null),
                        ),
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
      return t.status != TodoStatus.cancelled &&
          _isSameDay(t.createdAt, date);
    }).toList()
      ..sort((a, b) {
        if (a.isStarred && !b.isStarred) return -1;
        if (!a.isStarred && b.isStarred) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Widget _buildTodoList(List<TodoEntity> todos) {
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ===== 分类管理弹窗 =====

  void _showCategoryManager(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final cats = ref.watch(todoCategoriesProvider);
          return AlertDialog(
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
                          controller: ctrl,
                          decoration: const InputDecoration(
                            hintText: '新分类名称',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.blue),
                        onPressed: () {
                          if (ctrl.text.trim().isNotEmpty) {
                            ref
                                .read(todoCategoriesProvider.notifier)
                                .add(ctrl.text.trim());
                            ctrl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  ...cats.map((cat) => ListTile(
                        dense: true,
                        title: Text(cat),
                        trailing: cat == '生活' || cat == '工作'
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () => ref
                                    .read(todoCategoriesProvider.notifier)
                                    .remove(cat),
                              ),
                      )),
                  if (cats.length <= 2)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('至少保留一个分类',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
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
          );
        },
      ),
    );
  }
}
