/// 日报详情页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/review_providers.dart';

class DailyReviewDetailPage extends ConsumerWidget {
  final String dateStr; // yyyy-MM-dd

  const DailyReviewDetailPage({super.key, required this.dateStr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final reviewAsync = ref.watch(dailyReviewProvider(date));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, ref, date, reviewAsync.valueOrNull),
            Expanded(
              child: reviewAsync.when(
                data: (review) {
                  if (review == null) {
                    return const Center(
                      child: Text(
                        '该日没有复盘记录',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }
                  return _buildContent(context, review);
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('加载中...', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
                error: (err, _) {
                  // 首次加载常见超时错误，刷新后缓存可正常读取
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: AppColors.muted,
                        ),
                        const SizedBox(height: 12),
                        const Text('加载失败，请重试'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              ref.invalidate(dailyReviewProvider(date)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    DailyReviewEntity? review,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left),
            label: const Text('返回'),
          ),
          const Expanded(
            child: Text(
              '复盘详情',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: review == null
                ? null
                : () => _shareReview(context, review),
            child: const Text('分享'),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: '对话查看/编辑',
            onPressed: () => context.push('/review/daily/edit/$dateStr'),
          ),
          if (review != null)
            PopupMenuButton<String>(
              tooltip: '更多',
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'delete') _confirmDelete(context, ref, date);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, DailyReviewEntity review) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Text(
          _formatFullDate(review.date),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '记录时间：${_formatTime(review.createdAt)}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 16),

        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _levelBadge(
                  '情绪状态',
                  _moodEmoji(review.moodLevel),
                  '${review.moodLevel} 分',
                  AppColors.orange,
                ),
              ),
              const _CardDivider(),
              Expanded(
                child: _levelBadge(
                  '能量水平',
                  _energyIcon(review.energyLevel),
                  '${review.energyLevel} 分',
                  AppColors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '日间执行情况',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              _factRow(
                Icons.check_circle_outline,
                '任务完成',
                '${review.completedTodoIds.length} 项',
                AppColors.green,
              ),
              if (review.pattingMinutes > 0) ...[
                const SizedBox(height: 8),
                _factRow(
                  Icons.diamond_outlined,
                  '文玩盘玩',
                  '${review.pattingMinutes} 分钟',
                  AppColors.primary,
                ),
              ],
              if (review.highlights != null &&
                  review.highlights!.isNotEmpty) ...[
                const Divider(height: 22),
                _miniSection('今日收获', review.highlights!),
              ],
              if (review.improvements != null &&
                  review.improvements!.isNotEmpty) ...[
                const Divider(height: 22),
                _miniSection('待改进', review.improvements!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        const AppSectionTitle(title: 'AI 复盘摘要', padding: EdgeInsets.zero),
        const SizedBox(height: 10),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _summaryBubble(review.summary, isUser: true),
              if (review.aiComment != null && review.aiComment!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _summaryBubble(review.aiComment!, isUser: false),
              ],
              if (review.aiSuggestion != null &&
                  review.aiSuggestion!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _summaryBubble(
                  'AI 建议：${review.aiSuggestion!}',
                  isUser: false,
                  icon: Icons.lightbulb_outline,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _levelBadge(String label, String icon, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          '$icon $value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _factRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _miniSection(String title, String content) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBubble(
    String content, {
    required bool isUser,
    IconData? icon,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 18),
          ),
          border: isUser ? null : Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.blue),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: isUser ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareReview(
    BuildContext context,
    DailyReviewEntity review,
  ) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: _buildShareText(review)),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失败: $e')));
      }
    }
  }

  String _buildShareText(DailyReviewEntity review) {
    final lines = <String>[
      '${_formatFullDate(review.date)} 复盘',
      '记录时间：${_formatTime(review.createdAt)}',
      '情绪：${review.moodLevel} 分，能量：${review.energyLevel} 分',
      '任务完成：${review.completedTodoIds.length} 项',
    ];

    if (review.pattingMinutes > 0) {
      lines.add('文玩盘玩：${review.pattingMinutes} 分钟');
    }
    if (review.summary.isNotEmpty) {
      lines
        ..add('')
        ..add('今日总结：')
        ..add(review.summary);
    }
    if (review.highlights != null && review.highlights!.isNotEmpty) {
      lines
        ..add('')
        ..add('今日收获：')
        ..add(review.highlights!);
    }
    if (review.improvements != null && review.improvements!.isNotEmpty) {
      lines
        ..add('')
        ..add('待改进：')
        ..add(review.improvements!);
    }
    if (review.aiComment != null && review.aiComment!.isNotEmpty) {
      lines
        ..add('')
        ..add('AI 评语：')
        ..add(review.aiComment!);
    }
    if (review.aiSuggestion != null && review.aiSuggestion!.isNotEmpty) {
      lines
        ..add('')
        ..add('AI 建议：')
        ..add(review.aiSuggestion!);
    }

    return lines.join('\n');
  }

  String _formatFullDate(DateTime date) =>
      '${date.month}月${date.day}日 ${_weekdayLabel(date.weekday)}';

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '星期一';
      case DateTime.tuesday:
        return '星期二';
      case DateTime.wednesday:
        return '星期三';
      case DateTime.thursday:
        return '星期四';
      case DateTime.friday:
        return '星期五';
      case DateTime.saturday:
        return '星期六';
      case DateTime.sunday:
        return '星期日';
      default:
        return '';
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

  String _energyIcon(int level) {
    switch (level) {
      case 1:
        return '🪫';
      case 2:
        return '🔋';
      case 3:
        return '⚡';
      case 4:
        return '⚡⚡';
      case 5:
        return '⚡⚡⚡';
      default:
        return '⚡';
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${date.year}-${date.month}-${date.day} 的复盘记录吗？'),
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
    );
    if (confirmed == true && context.mounted) {
      final repo = await ref.read(reviewRepositoryProvider.future);
      await repo.deleteDaily(date);
      // 同时 invalidate 所有相关缓存，确保首页、列表页实时刷新
      ref.invalidate(dailyReviewProvider(date));
      ref.invalidate(allDailyReviewsProvider);
      ref.invalidate(dailyListByMonthProvider);
      ref.invalidate(monthlyAvgMoodProvider);
      ref.invalidate(monthlyAvgEnergyProvider);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: AppColors.line);
  }
}
