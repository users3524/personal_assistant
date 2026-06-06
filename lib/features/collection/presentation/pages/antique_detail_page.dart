/// 藏品详情页。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';
import '../widgets/valuation_chart.dart';

class AntiqueDetailPage extends ConsumerStatefulWidget {
  final int itemId;

  const AntiqueDetailPage({super.key, required this.itemId});

  @override
  ConsumerState<AntiqueDetailPage> createState() => _AntiqueDetailPageState();
}

class _AntiqueDetailPageState extends ConsumerState<AntiqueDetailPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AntiqueEntity?>(
      future: ref
          .read(antiqueRepositoryProvider.future)
          .then((r) => r.getById(widget.itemId)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('藏品详情')),
            body: const Center(child: Text('藏品不存在')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(item.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => _handleAction(context, item, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑')),
                  const PopupMenuItem(value: 'patting', child: Text('盘玩打卡')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图片轮播
                _buildImageCarousel(item),
                // 基本信息
                _buildInfoCard(item),
                // 估值走势
                _buildValuationSection(item),
                // 盘玩日志
                _buildPattingSection(item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCarousel(AntiqueEntity item) {
    if (item.imagePaths.isEmpty) {
      return Container(
        height: 280,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: item.imagePaths.length,
        itemBuilder: (context, index) {
          return Image.file(
            File(item.imagePaths[index]),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(AntiqueEntity item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Chip(
                    label: Text(item.category, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (item.subtype != null) ...[
                const SizedBox(height: 4),
                Text(item.subtype!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        )),
              ],
              const Divider(height: 24),
              _infoRow('品相', item.conditionLabel),
              _infoRow('入手日期',
                  '${item.acquiredDate.year}-${item.acquiredDate.month.toString().padLeft(2, '0')}-${item.acquiredDate.day.toString().padLeft(2, '0')}'),
              if (item.acquiredPrice != null)
                _infoRow('入手价格', '¥${item.acquiredPrice!.toStringAsFixed(0)}'),
              if (item.sourceSeller != null)
                _infoRow('来源', item.sourceSeller!),
              if (item.currentValuation != null)
                _infoRow('当前估值', '¥${item.currentValuation!.toStringAsFixed(0)}',
                    valueColor: Colors.green),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const Divider(height: 16),
                Text('备注', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(item.notes!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                  fontSize: 14,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildValuationSection(AntiqueEntity item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('估值走势',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('记录估值'),
                    onPressed: () => _addValuation(item),
                  ),
                ],
              ),
              SizedBox(
                height: 200,
                child: ValuationChart(itemId: widget.itemId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPattingSection(AntiqueEntity item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('盘玩日志',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('打卡'),
                    onPressed: () => _addPattingLog(item),
                  ),
                ],
              ),
              _buildPattingLogList(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPattingLogList(AntiqueEntity item) {
    return FutureBuilder<List<PattingLogEntity>>(
      future: ref
          .read(antiqueRepositoryProvider.future)
          .then((r) => r.getPattingLogs(widget.itemId)),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('暂无盘玩记录', style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(
          children: snapshot.data!.take(5).map((log) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.timer, size: 20),
              title: Text(
                  '${log.date.month}/${log.date.day}  ${log.methodLabel}  ${log.durationMinutes}分钟'),
              trailing: log.note != null
                  ? IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      onPressed: () => _showLogNote(context, log),
                    )
                  : null,
            );
          }).toList(),
        );
      },
    );
  }

  void _addValuation(AntiqueEntity item) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录估值'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '估值金额（元）',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null) return;
              final repo = await ref.read(antiqueRepositoryProvider.future);
              await repo.addValuation(ValuationRecordEntity(
                itemId: widget.itemId,
                date: DateTime.now(),
                amount: amount,
              ));
              if (context.mounted) Navigator.pop(context);
              setState(() {});
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _addPattingLog(AntiqueEntity item) {
    final durationCtrl = TextEditingController(text: '30');
    String method = 'bare_hand';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('盘玩打卡'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '盘玩时长（分钟）',
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'bare_hand', label: Text('净手盘')),
                  ButtonSegment(value: 'glove', label: Text('手套盘')),
                ],
                selected: {method},
                onSelectionChanged: (sel) =>
                    setDialogState(() => method = sel.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final minutes = int.tryParse(durationCtrl.text) ?? 30;
                final repo = await ref.read(antiqueRepositoryProvider.future);
                await repo.addPattingLog(PattingLogEntity(
                  itemId: widget.itemId,
                  date: DateTime.now(),
                  durationMinutes: minutes,
                  method: method,
                ));
                if (context.mounted) Navigator.pop(context);
                setState(() {});
              },
              child: const Text('打卡'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogNote(BuildContext context, PattingLogEntity log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('盘玩备注'),
        content: Text(log.note ?? '无'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    AntiqueEntity item,
    String action,
  ) {
    switch (action) {
      case 'edit':
        context.push('/collection/${item.id}/edit');
        break;
      case 'patting':
        _addPattingLog(item);
        break;
      case 'delete':
        _confirmDelete(context, item);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, AntiqueEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${item.name}」吗？\n所有图片、估值记录和盘玩日志也将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(antiqueListProvider.notifier).deleteItem(item.id!);
      if (mounted) context.pop();
    }
  }
}
