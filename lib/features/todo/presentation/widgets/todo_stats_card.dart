/// 待办统计仪表盘卡片。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/todo_providers.dart';

class TodoStatsCard extends ConsumerWidget {
  const TodoStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayCompleted = ref.watch(todayCompletedCountProvider).valueOrNull ?? 0;
    final todayTotal = ref.watch(todayTotalCountProvider).valueOrNull ?? 0;
    final weeklyRate = ref.watch(weeklyCompletionRateProvider).valueOrNull ?? 0.0;
    final delayRate = ref.watch(delayRateProvider).valueOrNull ?? 0.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              icon: Icons.today,
              label: '今日',
              value: '$todayCompleted/$todayTotal',
              color: Colors.blue,
            ),
            _buildDivider(),
            _buildStatItem(
              context,
              icon: Icons.receipt_long,
              label: '本周完成率',
              value: '${(weeklyRate * 100).toInt()}%',
              color: Colors.green,
            ),
            _buildDivider(),
            _buildStatItem(
              context,
              icon: Icons.warning_amber,
              label: '拖延率',
              value: '${(delayRate * 100).toInt()}%',
              color: delayRate > 0.3 ? Colors.red : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.shade300,
    );
  }
}
