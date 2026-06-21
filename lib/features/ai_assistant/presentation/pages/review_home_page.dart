/// AI 复盘首页 — 日报/周报入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/services/iso_week.dart';
import '../providers/review_providers.dart';

class ReviewHomePage extends ConsumerWidget {
  const ReviewHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 归一化到午夜，确保 family provider 参数稳定、不重复加载
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final todayReview = ref.watch(dailyReviewProvider(now));
    final isoWeek = ref.watch(currentIsoWeekProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 复盘'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _showStats(context),
            tooltip: '数据看板',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 今日状态卡片
          _buildTodayCard(context, ref, todayReview, now),
          const SizedBox(height: 16),

          // AI 复盘入口
          _buildReviewEntry(context, todayReview, now),
          const SizedBox(height: 24),

          // 本周周报
          _buildWeeklySection(context, ref, isoWeek),
          const SizedBox(height: 24),

          // 历史日报
          _buildHistorySection(context, ref),
        ],
      ),
    );
  }

  Widget _buildTodayCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<DailyReviewEntity?> todayReview,
    DateTime now,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '${now.month}/${now.day}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${now.year}年${now.month}月${now.day}日',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  todayReview.when(
                    data: (review) => Text(
                      review != null ? '今日已复盘 ✓' : '今日尚未复盘',
                      style: TextStyle(
                        color: review != null ? Colors.green : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    loading: () => const Text('加载中...'),
                    error: (_, __) => const Text('加载失败'),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.check_circle,
              color: todayReview.valueOrNull != null
                  ? Colors.green
                  : Colors.grey.shade300,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewEntry(
    BuildContext context,
    AsyncValue<DailyReviewEntity?> todayReview,
    DateTime now,
  ) {
    final hasReviewed = todayReview.valueOrNull != null;
    final review = todayReview.valueOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('AI 每日复盘', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasReviewed ? '今日复盘已完成，可以查看或继续对话。' : '回顾今天的工作与生活，让 AI 帮你总结和提升。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            // 显示可改进点（如有）
            if (hasReviewed &&
                review!.improvements != null &&
                review.improvements!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📌 ${review.improvements}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.brown,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/review/daily/new'),
                icon: Icon(hasReviewed ? Icons.refresh : Icons.edit),
                label: Text(hasReviewed ? '查看/继续对话' : '开始今日复盘'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySection(
    BuildContext context,
    WidgetRef ref,
    IsoWeek isoWeek,
  ) {
    final key = isoWeek.year * 100 + isoWeek.weekNumber;
    final weeklyAsync = ref.watch(weeklyReportByYearWeekProvider(key));
    final now = DateTime.now();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_view_week,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${isoWeek.year} 年第 ${isoWeek.weekNumber} 周周报',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                weeklyAsync.when(
                  data: (report) => Chip(
                    label: Text(
                      report != null ? '已生成' : '未生成',
                      style: TextStyle(
                        fontSize: 12,
                        color: report != null ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!weeklyAsync.hasValue || weeklyAsync.valueOrNull == null)
              Text(
                isWeekend ? '📊 周末了！本周有足够的数据，可以生成周报了。' : '每天坚持复盘，周末自动汇总生成周报。',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  RouteNames.weeklyReportDetailPath(
                    isoWeek.weekNumber,
                    year: isoWeek.year,
                  ),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  isWeekend && (weeklyAsync.valueOrNull == null)
                      ? '生成周报'
                      : '查看 / 生成周报',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthAsync = ref.watch(dailyListByMonthProvider(now.month));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${now.month}月复盘记录',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showMonthlyCalendar(context),
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            monthAsync.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '本月暂无复盘记录',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(
                  children: reviews.take(5).map((r) {
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _moodColor(
                            r.moodLevel,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _moodEmoji(r.moodLevel),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      title: Text(
                        '${r.date.month}/${r.date.day}  ${r.summary}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => context.push(
                        '/review/daily/${r.date.toIso8601String().split('T')[0]}',
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text('加载失败: $err'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStats(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _StatsSheet(),
    );
  }

  void _showMonthlyCalendar(BuildContext context) {
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MonthlyCalendarSheet(
        year: now.year,
        month: now.month,
        moodColor: _moodColor,
        moodEmoji: _moodEmoji,
      ),
    );
  }

  Color _moodColor(int level) {
    switch (level) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _moodEmoji(int level) {
    switch (level) {
      case 1:
        return '😞';
      case 2:
        return '😐';
      case 3:
        return '🙂';
      case 4:
        return '😊';
      case 5:
        return '😄';
      default:
        return '😐';
    }
  }
}

// ===== 统计面板 =====

class _MonthlyCalendarSheet extends ConsumerWidget {
  final int year;
  final int month;
  final Color Function(int level) moodColor;
  final String Function(int level) moodEmoji;

  const _MonthlyCalendarSheet({
    required this.year,
    required this.month,
    required this.moodColor,
    required this.moodEmoji,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = year * 100 + month;
    final reviewsAsync = ref.watch(dailyListByYearMonthProvider(key));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '$year年$month月复盘日历',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWeekHeader(context),
            const SizedBox(height: 8),
            reviewsAsync.when(
              data: (reviews) => _buildCalendarGrid(context, reviews),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('加载失败: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekHeader(BuildContext context) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    List<DailyReviewEntity> reviews,
  ) {
    final reviewsByDay = {
      for (final review in reviews) review.date.day: review,
    };
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: List.generate(7, (columnIndex) {
              final cellIndex = rowIndex * 7 + columnIndex;
              final day = cellIndex - leadingBlanks + 1;
              if (day < 1 || day > daysInMonth) {
                return const Expanded(child: SizedBox(height: 54));
              }
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _CalendarDayTile(
                    day: day,
                    review: reviewsByDay[day],
                    moodColor: moodColor,
                    moodEmoji: moodEmoji,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  final int day;
  final DailyReviewEntity? review;
  final Color Function(int level) moodColor;
  final String Function(int level) moodEmoji;

  const _CalendarDayTile({
    required this.day,
    required this.review,
    required this.moodColor,
    required this.moodEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final review = this.review;
    final hasReview = review != null;
    final color = hasReview ? moodColor(review.moodLevel) : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: hasReview
          ? () {
              Navigator.pop(context);
              context.push(
                '/review/daily/${review.date.toIso8601String().split('T')[0]}',
              );
            }
          : null,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: hasReview
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasReview
                ? color.withValues(alpha: 0.35)
                : Colors.grey.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasReview ? FontWeight.w700 : FontWeight.w500,
                color: hasReview ? color : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasReview ? moodEmoji(review.moodLevel) : '·',
              style: TextStyle(
                fontSize: hasReview ? 15 : 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSheet extends ConsumerWidget {
  const _StatsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avgMood = ref.watch(monthlyAvgMoodProvider).valueOrNull ?? 0;
    final avgEnergy = ref.watch(monthlyAvgEnergyProvider).valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本月数据概览', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard(
                context,
                '平均情绪',
                avgMood.toStringAsFixed(1),
                Icons.face,
              ),
              const SizedBox(width: 12),
              _statCard(
                context,
                '平均能量',
                avgEnergy.toStringAsFixed(1),
                Icons.bolt,
              ),
              const SizedBox(width: 12),
              _statCard(context, '复盘天数', '0', Icons.calendar_today),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
