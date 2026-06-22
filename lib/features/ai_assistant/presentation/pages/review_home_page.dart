/// AI 复盘首页 — 日报/周报入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 88),
          children: [
            AppPageHeader(
              title: 'AI 复盘',
              subtitle: '把今天沉淀成明天能用的经验',
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.bar_chart),
                onPressed: () => _showStats(context),
                tooltip: '数据看板',
              ),
            ),
            const SizedBox(height: 16),
            _buildReviewEntry(context, todayReview, now),
            const SizedBox(height: 14),
            _buildWeeklySection(context, ref, isoWeek),
            const SizedBox(height: 20),
            _buildHistorySection(context, ref),
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

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryLight.withValues(alpha: 0.55),
              AppColors.card,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Center(
                    child: Text(
                      '${now.month}/${now.day}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'AI 每日复盘',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          AppPill(
                            label: hasReviewed ? '已完成' : '未完成',
                            color: hasReviewed
                                ? AppColors.green
                                : AppColors.orange,
                            icon: hasReviewed
                                ? Icons.check_circle
                                : Icons.pending_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${now.year}年${now.month}月${now.day}日',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hasReviewed ? '今日复盘已完成，可以查看或继续对话。' : '回顾今天的工作与生活，让 AI 帮你总结和提升。',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            if (hasReviewed &&
                review!.improvements != null &&
                review.improvements!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 17,
                      color: AppColors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        review.improvements!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.ink,
                          height: 1.4,
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

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push(
        RouteNames.weeklyReportDetailPath(
          isoWeek.weekNumber,
          year: isoWeek.year,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_view_week, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isoWeek.year} 年第 ${isoWeek.weekNumber} 周周报',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isWeekend ? '周末可生成本周总结' : '每天复盘，周末自动汇总',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          weeklyAsync.when(
            data: (report) => AppPill(
              label: report != null ? '已生成' : '去生成',
              color: report != null ? AppColors.green : AppColors.primary,
              icon: report != null ? Icons.check_circle : Icons.auto_awesome,
              isFilled: report == null,
            ),
            loading: () => const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) =>
                const Icon(Icons.chevron_right, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthAsync = ref.watch(dailyListByMonthProvider(now.month));
    final avgMood = ref.watch(monthlyAvgMoodProvider).valueOrNull ?? 0;
    final avgEnergy = ref.watch(monthlyAvgEnergyProvider).valueOrNull ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          title: '${now.month}月复盘记录',
          padding: EdgeInsets.zero,
          trailing: TextButton(
            onPressed: () => _showMonthlyCalendar(context),
            child: const Text('查看全部'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppMetricCard(
                label: '平均情绪',
                value: avgMood.toStringAsFixed(1),
                color: AppColors.orange,
                icon: Icons.face_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppMetricCard(
                label: '平均能量',
                value: avgEnergy.toStringAsFixed(1),
                color: AppColors.green,
                icon: Icons.bolt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: monthAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    '本月暂无复盘记录',
                    style: TextStyle(color: AppColors.muted),
                  ),
                );
              }
              return Column(
                children: reviews.take(5).map((r) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _moodColor(r.moodLevel).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    subtitle: Text(
                      '情绪 ${r.moodLevel} · 能量 ${r.energyLevel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push(
                      '/review/daily/${r.date.toIso8601String().split('T')[0]}',
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(18),
              child: Text('加载失败: $err'),
            ),
          ),
        ),
      ],
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
