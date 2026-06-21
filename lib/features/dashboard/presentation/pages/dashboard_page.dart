import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../ai_assistant/presentation/providers/review_providers.dart';
import '../../../collection/domain/entities/antique_entity.dart';
import '../../../collection/presentation/providers/antique_providers.dart';
import '../../../resume/domain/entities/resume_entity.dart';
import '../../../resume/presentation/providers/resume_providers.dart';
import '../../../todo/domain/entities/todo_entity.dart';
import '../../../todo/presentation/providers/todo_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayCompleted = ref.watch(todayCompletedCountProvider).valueOrNull;
    final todayTotal = ref.watch(todayTotalCountProvider).valueOrNull;
    final todayTodos = ref.watch(todayTodosProvider).valueOrNull ?? const [];
    final antiques = ref.watch(antiqueListProvider).valueOrNull ?? const [];
    final todayPattingMinutes = ref
        .watch(todayPattingDurationProvider)
        .valueOrNull;
    final durationByItem =
        ref.watch(totalPattingDurationProvider).valueOrNull ?? const {};
    final todayReview = ref.watch(dailyReviewProvider(_today())).valueOrNull;
    final resume = ref.watch(resumeDataProvider).valueOrNull;

    final activeTodos = todayTodos.where((todo) => todo.isActive).take(3);
    final featuredAntiques = antiques.take(2).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayCompletedCountProvider);
            ref.invalidate(todayTotalCountProvider);
            ref.invalidate(todayTodosProvider);
            ref.invalidate(antiqueListProvider);
            ref.invalidate(todayPattingDurationProvider);
            ref.invalidate(totalPattingDurationProvider);
            ref.invalidate(dailyReviewProvider);
            ref.invalidate(resumeDataProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
            children: [
              _Header(onSettings: () => context.push(RouteNames.settings)),
              const SizedBox(height: 16),
              _StatStrip(
                items: [
                  _StatItem(
                    label: '今日任务',
                    value: _valueOrDash(todayTotal),
                    color: AppColors.ink,
                  ),
                  _StatItem(
                    label: '已完成',
                    value: _valueOrDash(todayCompleted),
                    color: AppColors.green,
                  ),
                  _StatItem(
                    label: '待复盘',
                    value: todayReview == null ? '1' : '0',
                    color: AppColors.orange,
                  ),
                  _StatItem(
                    label: '今日盘玩',
                    value: _pattingText(todayPattingMinutes),
                    color: AppColors.wood,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                title: '今日待办',
                action: '查看全部',
                onTap: () => context.go(RouteNames.todoList),
              ),
              const SizedBox(height: 10),
              _TaskCard(
                todos: activeTodos.toList(),
                onCreate: () => context.push(RouteNames.todoNew),
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: '今日文玩养护',
                action: '去盘串',
                onTap: () => context.go(RouteNames.collectionList),
              ),
              const SizedBox(height: 10),
              _AntiqueCard(
                items: featuredAntiques,
                durationByItem: durationByItem,
                onCreate: () => context.push(RouteNames.collectionNew),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: '今日复盘',
                      subtitle: todayReview == null ? '状态：未完成' : '状态：已沉淀',
                      buttonLabel: todayReview == null ? '开始复盘' : '查看复盘',
                      onTap: () {
                        if (todayReview == null) {
                          context.push(RouteNames.dailyReviewNew);
                        } else {
                          context.push(
                            RouteNames.dailyReviewDetailPath(
                              _dateKey(DateTime.now()),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: '履历沉淀',
                      subtitle: _resumeSubtitle(resume),
                      buttonLabel: '查看简历',
                      outlined: true,
                      onTap: () => context.go(RouteNames.resumeHome),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _valueOrDash(int? value) => value == null ? '-' : '$value';

  static String _pattingText(int? minutes) {
    if (minutes == null) return '-';
    if (minutes <= 0) return '0m';
    if (minutes < 1000) return '${minutes}m';
    return '${(minutes / 60).round()}h';
  }

  static String _resumeSubtitle(ResumeData? resume) {
    if (resume == null) return '项目经历准备中';
    final count = resume.projects.where((project) => project.isVisible).length;
    if (count == 0) return '还没有可见项目';
    return '$count 个项目可沉淀';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今天也慢慢推进',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '任务、盘玩、复盘和履历都在这里',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: onSettings,
          tooltip: '设置',
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i != items.length - 1)
              Container(width: 1, height: 34, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.todos, required this.onCreate});

  final List<TodoEntity> todos;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: todos.isEmpty
          ? _EmptyCard(
              icon: Icons.check_circle_outline,
              title: '今天没有待办',
              action: '新建任务',
              onTap: onCreate,
            )
          : Column(
              children: [
                for (var i = 0; i < todos.length; i++) ...[
                  _TodoRow(todo: todos[i]),
                  if (i != todos.length - 1)
                    const Divider(height: 1, color: AppColors.line),
                ],
              ],
            ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo});

  final TodoEntity todo;

  @override
  Widget build(BuildContext context) {
    final todoId = todo.id;
    return InkWell(
      onTap: todoId == null
          ? null
          : () => context.push(RouteNames.todoDetailPath(todoId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.isDone ? AppColors.green : Colors.transparent,
                border: Border.all(
                  color: todo.isDone ? AppColors.green : AppColors.line,
                  width: 2,
                ),
              ),
              child: todo.isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: todo.isDone ? AppColors.muted : AppColors.ink,
                      decoration: todo.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Pill(text: todo.category, color: AppColors.blue),
                      if (todo.subtasks.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '子任务 ${todo.subtasks.where((t) => t.isDone).length}/${todo.subtasks.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (todo.isStarred)
              const Icon(Icons.star, size: 18, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

class _AntiqueCard extends StatelessWidget {
  const _AntiqueCard({
    required this.items,
    required this.durationByItem,
    required this.onCreate,
  });

  final List<AntiqueEntity> items;
  final Map<int, int> durationByItem;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _SurfaceCard(
        child: _EmptyCard(
          icon: Icons.diamond_outlined,
          title: '还没有藏品记录',
          action: '添加藏品',
          onTap: onCreate,
        ),
      );
    }

    return Column(
      children: [
        for (final item in items) ...[
          _AntiqueRow(item: item, minutes: _minutesFor(item)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  int _minutesFor(AntiqueEntity item) {
    final itemId = item.id;
    if (itemId == null) return 0;
    return durationByItem[itemId] ?? 0;
  }
}

class _AntiqueRow extends StatelessWidget {
  const _AntiqueRow({required this.item, required this.minutes});

  final AntiqueEntity item;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final itemId = item.id;
    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: itemId == null
            ? null
            : () => context.push(RouteNames.collectionDetailPath(itemId)),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.diamond, color: AppColors.wood),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '累计盘玩 $minutes 分钟',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            _Pill(text: item.category, color: AppColors.orange),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    this.outlined = false,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final button = outlined
        ? OutlinedButton(onPressed: onTap, child: Text(buttonLabel))
        : FilledButton(onPressed: onTap, child: Text(buttonLabel));

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          button,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
