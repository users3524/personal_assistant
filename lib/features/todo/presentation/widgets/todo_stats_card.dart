/// 待办统计仪表盘卡片。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../providers/todo_providers.dart';

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

    return AppSurfaceCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.task_alt,
              label: '今日完成',
              value: '$todayCompleted / $todayTotal',
              color: todayCompleted == todayTotal && todayTotal > 0
                  ? AppColors.green
                  : AppColors.blue,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildStatItem(
              icon: Icons.trending_up,
              label: '本周达成',
              value: '${(weeklyRate * 100).toInt()}%',
              color: weeklyRate > 0.8 ? AppColors.green : AppColors.orange,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildStatItem(
              icon: Icons.timer_off_outlined,
              label: '历史拖延',
              value: '${(delayRate * 100).toInt()}%',
              color: delayRate > 0.3 ? AppColors.red : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(width: 1, height: 52, color: AppColors.line);
}
