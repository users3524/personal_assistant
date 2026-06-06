/// AI 复盘首页 — 日报/周报入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/review_providers.dart';

class ReviewHomePage extends ConsumerWidget {
  const ReviewHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayReview = ref.watch(dailyReviewProvider(now));
    final weekNumber = ref.watch(currentWeekNumberProvider);

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
          _buildWeeklySection(context, ref, weekNumber),
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                Text(
                  'AI 每日复盘',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasReviewed
                  ? '今日复盘已完成，可以查看或重新生成。'
                  : '回顾今天的工作与生活，让 AI 帮你总结和提升。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/review/daily/new'),
                icon: Icon(hasReviewed ? Icons.refresh : Icons.edit),
                label: Text(hasReviewed ? '查看/重新复盘' : '开始今日复盘'),
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
    int weekNumber,
  ) {
    final weeklyAsync = ref.watch(weeklyReportProvider(weekNumber));

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
                  '第 $weekNumber 周周报',
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/review/weekly/$weekNumber'),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('查看 / 生成周报'),
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
                          color: _moodColor(r.moodLevel).withValues(alpha: 0.15),
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
    // TODO: 月度日历视图
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('月度视图即将上线')),
    );
  }

  Color _moodColor(int level) {
    switch (level) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      case 4: return Colors.lightGreen;
      case 5: return Colors.green;
      default: return Colors.grey;
    }
  }

  String _moodEmoji(int level) {
    switch (level) {
      case 1: return '😞';
      case 2: return '😐';
      case 3: return '🙂';
      case 4: return '😊';
      case 5: return '😄';
      default: return '😐';
    }
  }
}

// ===== 统计面板 =====

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
              _statCard(context, '平均情绪', avgMood.toStringAsFixed(1), Icons.face),
              const SizedBox(width: 12),
              _statCard(context, '平均能量', avgEnergy.toStringAsFixed(1), Icons.bolt),
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
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
