/// 日报详情页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        title: Text('$dateStr 复盘'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: '对话查看/编辑',
            onPressed: () => context.push('/review/daily/edit/$dateStr'),
          ),
          if (reviewAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: '删除',
              onPressed: () => _confirmDelete(context, ref, date),
            ),
        ],
      ),
      body: reviewAsync.when(
        data: (review) {
          if (review == null) {
            return const Center(child: Text('该日没有复盘记录'));
          }
          return _buildContent(context, review);
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('加载中...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        error: (err, _) {
          // 首次加载常见超时错误，刷新后缓存可正常读取
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('加载失败，请重试'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(dailyReviewProvider(date)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, DailyReviewEntity review) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 情绪能量卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _levelBadge('情绪', _moodEmoji(review.moodLevel),
                    review.moodLevel),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
                _levelBadge('能量', _energyIcon(review.energyLevel),
                    review.energyLevel),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 总结
        _sectionCard(context, '今日总结', review.summary),
        if (review.highlights != null) ...[
          const SizedBox(height: 12),
          _sectionCard(context, '今日收获', review.highlights!,
              icon: Icons.emoji_events, color: Colors.amber),
        ],
        if (review.improvements != null) ...[
          const SizedBox(height: 12),
          _sectionCard(context, '今日不足', review.improvements!,
              icon: Icons.trending_up, color: Colors.orange),
        ],
        if (review.aiComment != null) ...[
          const SizedBox(height: 16),
          _sectionCard(context, 'AI 评语', review.aiComment!,
              icon: Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
              bgColor: Theme.of(context).colorScheme.primaryContainer),
        ],
        if (review.aiSuggestion != null) ...[
          const SizedBox(height: 12),
          _sectionCard(context, 'AI 建议', review.aiSuggestion!,
              icon: Icons.lightbulb, color: Colors.blue),
        ],
        if (review.completedTodoIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '完成了 ${review.completedTodoIds.length} 个待办',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (review.pattingMinutes > 0)
                    Text(
                      '盘玩 ${review.pattingMinutes} 分钟',
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _levelBadge(String label, String emoji, int level) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text('$level/5',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _sectionCard(
    BuildContext context,
    String title,
    String content, {
    IconData? icon,
    Color? color,
    Color? bgColor,
  }) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                ],
                Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
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

  String _energyIcon(int level) {
    switch (level) {
      case 1: return '🪫';
      case 2: return '🔋';
      case 3: return '⚡';
      case 4: return '⚡⚡';
      case 5: return '⚡⚡⚡';
      default: return '⚡';
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DateTime date) async {
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
      ref.invalidate(dailyReviewProvider(date));
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
