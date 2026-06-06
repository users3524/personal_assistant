/// 估值走势折线图组件。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../data/repositories/antique_repository_impl.dart';
import '../../domain/entities/antique_entity.dart';

class ValuationChart extends ConsumerWidget {
  final int itemId;

  const ValuationChart({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ValuationRecordEntity>>(
      future: ref
          .read(antiqueRepositoryProvider.future)
          .then((r) => r.getValuations(itemId)),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('暂无估值记录', style: TextStyle(color: Colors.grey)),
          );
        }

        final records = snapshot.data!;
        // 按日期排序（旧到新）
        records.sort((a, b) => a.date.compareTo(b.date));

        if (records.length < 2) {
          // 只有一条记录，展示单点
          return Center(
            child: Text(
              '当前估值: ¥${records.first.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          );
        }

        final minY = records.map((r) => r.amount).reduce((a, b) => a < b ? a : b);
        final maxY = records.map((r) => r.amount).reduce((a, b) => a > b ? a : b);
        final range = maxY - minY;
        final padding = range == 0 ? 100.0 : range * 0.2;

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY + padding * 2) / 4,
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    '¥${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= records.length) {
                      return const SizedBox();
                    }
                    return Text(
                      '${records[index].date.month}/${records[index].date.day}',
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: records.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value.amount,
                  );
                }).toList(),
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.blue,
                      strokeWidth: 0,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blue.withOpacity(0.1),
                ),
              ),
            ],
            minY: minY - padding,
            maxY: maxY + padding,
          ),
        );
      },
    );
  }
}
