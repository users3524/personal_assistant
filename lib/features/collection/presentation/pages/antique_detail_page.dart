/// 盘串详情页 — 时间线 + 盘玩打卡 + 情感记录。
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';

class AntiqueDetailPage extends ConsumerStatefulWidget {
  final int itemId;
  final int? highlightLogId;

  const AntiqueDetailPage({super.key, required this.itemId, this.highlightLogId});

  @override
  ConsumerState<AntiqueDetailPage> createState() => _AntiqueDetailPageState();
}

class _AntiqueDetailPageState extends ConsumerState<AntiqueDetailPage> {
  late Future<AntiqueEntity?> _itemFuture;
  late Future<List<PattingLogEntity>> _logsFuture;
  final _pageController = PageController();
  final _currentPage = ValueNotifier<int>(0);

  // 缓存的打卡记录 — banner 从中取最新照片
  List<PattingLogEntity>? _cachedLogs;

  // 高亮动画 — 月历点击跳转时闪烁
  int? _highlightLogId;
  bool _isHighlighting = false;

  @override
  void initState() {
    super.initState();
    _itemFuture = _loadItem();
    _logsFuture = _loadLogs().then((logs) {
      _cachedLogs = logs;
      return logs;
    });
    _highlightLogId = widget.highlightLogId;
    if (_highlightLogId != null) {
      _startHighlightAnimation();
    }
  }

  Future<void> _startHighlightAnimation() async {
    // 等数据库加载完成
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isHighlighting = true);
    // 闪烁 3 次
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _isHighlighting = !_isHighlighting);
    }
    setState(() {
      _isHighlighting = false;
      _highlightLogId = null;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  Future<AntiqueEntity?> _loadItem() {
    return ref
        .read(antiqueRepositoryProvider.future)
        .then((r) => r.getById(widget.itemId));
  }

  Future<List<PattingLogEntity>> _loadLogs() {
    return ref
        .read(antiqueRepositoryProvider.future)
        .then((r) => r.getPattingLogs(widget.itemId));
  }

  void _refreshPage() {
    if (!mounted) return;
    setState(() {
      _itemFuture = _loadItem();
      _logsFuture = _loadLogs().then((logs) {
        _cachedLogs = logs;
        return logs;
      });
    });
  }

  /// 获取 Banner 要展示的图片列表
  /// 优先取最新一条有照片的打卡记录，没有则用藏品自己的图片
  List<String> _getBannerImages(AntiqueEntity item) {
    if (_cachedLogs != null) {
      final sorted = List<PattingLogEntity>.from(_cachedLogs!)
        ..sort((a, b) => b.date.compareTo(a.date));
      for (final log in sorted) {
        if (log.photoPaths.isNotEmpty) return log.photoPaths;
      }
    }
    return item.imagePaths;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AntiqueEntity?>(
      future: _itemFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('盘串详情')),
            body: const Center(child: Text('宝贝不存在')),
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
                  const PopupMenuItem(value: 'compare', child: Text('对比')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图片轮播（最新打卡照片优先）
                _buildImageCarousel(item, _getBannerImages(item)),
                // 基本信息 + 情感卡片
                _buildInfoCard(item),
                // 本月盘玩热力图
                _buildPattingHeatmap(item),
                // 盘玩打卡时间线
                _buildPattingTimeline(item),
                // 底部留白，给 FAB 让位
                const SizedBox(height: 80),
              ],
            ),
          ),
          floatingActionButton: Container(
            margin: const EdgeInsets.only(bottom: 8, right: 4),
            child: FloatingActionButton.extended(
              label: const Text('打卡'),
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              onPressed: () => _addPattingCheckin(item),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCarousel(AntiqueEntity item, List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 260,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.diamond_outlined, size: 64, color: Colors.grey),
        ),
      );
    }

    if (images.length == 1) {
      return SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => _showFullScreenImage(context, images[0]),
              onLongPress: () => _showImageActions(context, images[0]),
              child: Image.file(File(images[0]), fit: BoxFit.cover, width: double.infinity,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
              ),
            ),
            // 显示照片来源标签
            Positioned(top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: Text(_cachedLogs != null && _cachedLogs!.any((l) => l.photoPaths.contains(images[0]))
                    ? '最新打卡' : '藏品照片', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => _currentPage.value = i,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => _showFullScreenImage(context, images[index]),
                    onLongPress: () => _showImageActions(context, images[index]),
                    child: Image.file(File(images[index]), fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
                    ),
                  ),
                  Positioned(top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                      child: Text(_cachedLogs != null && _cachedLogs!.any((l) => l.photoPaths.contains(images[index]))
                          ? '最新打卡' : '藏品照片', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _currentPage,
          builder: (_, page, __) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) => Container(
              width: i == page ? 8 : 6,
              height: i == page ? 8 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == page ? Colors.teal : Colors.grey.shade300,
              ),
            )),
          ),
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<int>(
          valueListenable: _currentPage,
          builder: (_, page, __) => Text('${page + 1} / ${images.length}',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildInfoCard(AntiqueEntity item) {
    // 计算拥有天数
    final daysOwned = DateTime.now().difference(item.acquiredDate).inDays;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称+分类
              Row(
                children: [
                  Expanded(
                    child: Text(item.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Chip(
                    label: Text(item.category, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.teal.withValues(alpha: 0.1),
                  ),
                ],
              ),
              if (item.subtype != null) ...[
                const SizedBox(height: 4),
                Text(item.subtype!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.grey)),
              ],
              const SizedBox(height: 8),
              // 情感价值卡片
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade50,
                      Colors.orange.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.pink, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '陪伴 $daysOwned 天',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                          if (item.description != null && item.description!.isNotEmpty)
                            Text(
                              item.description!,
                              style: const TextStyle(fontSize: 12, color: Colors.brown),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // 详细信息
              _infoRow('品相', item.conditionLabel),
              _infoRow(
                '入手日期',
                '${item.acquiredDate.year}-${item.acquiredDate.month.toString().padLeft(2, '0')}-${item.acquiredDate.day.toString().padLeft(2, '0')}',
              ),
              if (item.acquiredPrice != null)
                _infoRow('入手价格', '¥${item.acquiredPrice!.toStringAsFixed(0)}'),
              if (item.sourceSeller != null)
                _infoRow('来源', item.sourceSeller!),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const Divider(height: 12),
                Text('备注', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(item.notes!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        )),
              ],
              // 分类专属参数
              if (item.categoryMetadata != null && item.categoryMetadata!.isNotEmpty) ...[
                const Divider(height: 16),
                Text('详细参数', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                // 核桃品类三列显示（行名 | 左参数 | 右参数）
                if (item.category == '核桃') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // 表头
                        Row(
                          children: [
                            const SizedBox(width: 72, child: Text('参数', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(child: Center(child: Text('左', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)))),
                            Expanded(child: Center(child: Text('右', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)))),
                          ],
                        ),
                        const Divider(height: 8),
                        ...item.categoryMetadata!.entries.map((e) {
                          final parts = e.value.split(',');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 72,
                                  child: Text(e.key, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(parts.isNotEmpty ? parts[0].trim() : '', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.teal.shade700)),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(parts.length > 1 ? parts[1].trim() : '', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.orange.shade700)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ] else ...[
                  // 非核桃品类正常显示
                  ...item.categoryMetadata!.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(e.key, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ),
                          Expanded(
                            child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
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

  // ===== 本月盘玩热力图 =====

  Widget _buildPattingHeatmap(AntiqueEntity item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, size: 18, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text('本月打卡热力图',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<PattingLogEntity>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? <PattingLogEntity>[];
                  return _buildHeatmapGrid(logs);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid(List<PattingLogEntity> logs) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final daysInMonth = lastDay.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells + 6) ~/ 7;

    // 构建打卡日期集合（仅统计本月）
    final pattingDays = <int>{};
    for (final log in logs) {
      if (log.date.year == now.year && log.date.month == now.month) {
        pattingDays.add(log.date.day);
      }
    }

    // 按打卡次数分色：1次浅色，2次中色，3次+深色
    final pattingCount = <int, int>{};
    for (final log in logs) {
      if (log.date.year == now.year && log.date.month == now.month) {
        pattingCount[log.date.day] = (pattingCount[log.date.day] ?? 0) + 1;
      }
    }

    Color _heatColor(int count) {
      if (count == 0) return Colors.grey.shade100;
      if (count == 1) return Colors.orange.shade100;
      if (count <= 3) return Colors.orange.shade300;
      return Colors.orange.shade600;
    }

    return Column(
      children: [
        // 星期标签
        Row(
          children: ['一','二','三','四','五','六','日'].map((d) {
            return Expanded(
              child: Center(
                child: Text(d, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // 日期网格
        Table(
          children: List.generate(rows, (weekIndex) {
            return TableRow(
              children: List.generate(7, (colIndex) {
                final dayNum = weekIndex * 7 + colIndex - startWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(height: 28);
                }
                final count = pattingCount[dayNum] ?? 0;
                final isToday = dayNum == now.day;

                return Container(
                  height: 28,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: _heatColor(count),
                    borderRadius: BorderRadius.circular(4),
                    border: isToday ? Border.all(color: Colors.orange.shade800, width: 1.5) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : null,
                      color: count >= 3 ? Colors.white : null,
                    ),
                  ),
                );
              }),
            );
          }),
        ),
        const SizedBox(height: 6),
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _heatLegend(Colors.grey.shade100, '无'),
            const SizedBox(width: 8),
            _heatLegend(Colors.orange.shade100, '1次'),
            const SizedBox(width: 8),
            _heatLegend(Colors.orange.shade300, '2-3次'),
            const SizedBox(width: 8),
            _heatLegend(Colors.orange.shade600, '3次+'),
          ],
        ),
      ],
    );
  }

  Widget _heatLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      ],
    );
  }

  // ===== 盘玩打卡时间线 =====

  Widget _buildPattingTimeline(AntiqueEntity item) {
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
                  const Icon(Icons.timeline, size: 20, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text('盘玩时光',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              _buildTimelineList(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineList(AntiqueEntity item) {
    return FutureBuilder<List<PattingLogEntity>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.pan_tool_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('还没有盘玩记录',
                      style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('点击下方按钮打卡',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        final logs = snapshot.data!;
        final sorted = List<PattingLogEntity>.from(logs)
          ..sort((a, b) => b.date.compareTo(a.date));

        return Column(
          children: sorted.asMap().entries.map((entry) {
            final log = entry.value;
            final isFirst = entry.key == sorted.length - 1; // 最后一条是最早的
            final daysSinceAcquisition = log.date.difference(item.acquiredDate).inDays;
            final dayLabel = daysSinceAcquisition == 0 ? '入手当天' : '第${daysSinceAcquisition}天';
            // 日期时间：26/03/05 16:38
            final y = (log.date.year % 100).toString().padLeft(2, '0');
            final m = log.date.month.toString().padLeft(2, '0');
            final d = log.date.day.toString().padLeft(2, '0');
            final time = '${log.date.hour.toString().padLeft(2, '0')}:${log.date.minute.toString().padLeft(2, '0')}';
            final dateTimeStr = '$y/$m/$d $time';
            final hasPhoto = log.photoPaths.isNotEmpty;
            final isHighlighted = _highlightLogId != null && log.id == _highlightLogId;

            return IntrinsicHeight(
              key: log.id != null ? ValueKey('log_${log.id}') : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间线左侧：第N天
                  SizedBox(
                    width: 72,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dayLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ),
                  // 时间线圆点+线
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFirst ? Colors.teal : Colors.teal.shade200,
                          border: Border.all(
                            color: Colors.teal.shade100,
                            width: 3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.teal.shade100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 内容卡片
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      color: isHighlighted && _isHighlighting
                          ? Colors.amber.shade100
                          : Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dateTimeStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                // 编辑按钮
                                GestureDetector(
                                  onTap: () => _editPattingLog(item, log),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.edit, size: 14, color: Colors.grey),
                                  ),
                                ),
                                // 删除按钮
                                GestureDetector(
                                  onTap: () => _deletePattingLog(log),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 2),
                                    child: Icon(Icons.close, size: 16, color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                            if (log.note != null && log.note!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  log.note!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            if (hasPhoto) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: log.photoPaths.map((path) {
                                  return GestureDetector(
                                    onTap: () => _showFullScreenImage(context, path),
                                    onLongPress: () => _showImageActions(context, path),
                                    child: Container(
                                      width: 150,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 28),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
        }).toList(),
        );
      },
    );
  }

  // ===== 盘玩打卡 =====

  /// 将 XFile 保存到应用私有目录，返回真实文件路径。
  /// 和 antique_form_page 使用完全相同的逻辑。
  Future<String> _saveImageToAppDir(XFile photo) async {
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/patting_images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    final fileName = 'patting_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${imgDir.path}/$fileName');
    final bytes = await photo.readAsBytes();
    await dest.writeAsBytes(bytes);
    return 'patting_images/$fileName'; // 相对路径
  }

  /// 全屏查看图片 — 点击图片进入，再次点击任意位置退出
  void _showFullScreenImage(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          onLongPress: () => _showImageActions(context, path),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Center(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 长按图片弹出操作菜单（分享 / 保存到相册）
  void _showImageActions(BuildContext context, String path) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () {
                Navigator.pop(ctx);
                _shareImage(context, path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('保存到相册'),
              onTap: () {
                Navigator.pop(ctx);
                _saveImageToGallery(context, path);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 分享图片
  Future<void> _shareImage(BuildContext context, String path) async {
    try {
      final file = XFile(path);
      await Share.shareXFiles([file], text: '分享图片');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  /// 保存图片到系统相册
  Future<void> _saveImageToGallery(BuildContext context, String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片文件不存在')),
          );
        }
        return;
      }
      final bytes = await file.readAsBytes();
      // gal 需要先写入临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_save_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      await Gal.putImage(tempFile.path);
      // 清理临时文件
      await tempFile.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已保存到系统相册'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  void _addPattingCheckin(AntiqueEntity item) {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('记录此刻',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _doPickImage(item, picker, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                _doPickImage(item, picker, ImageSource.gallery);
              },
            ),
            const Divider(indent: 16, endIndent: 16, height: 8),
            ListTile(
              leading: const Icon(Icons.touch_app, color: Colors.grey),
              title: const Text('仅打卡（不拍照）'),
              subtitle: const Text('快速记录盘玩'),
              onTap: () {
                Navigator.pop(ctx);
                _showCheckinDialog(item, null);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 选图 → 保存到本地 → 弹对话框预览。
  /// 和 antique_form_page._pickImage 逻辑一致：先保存再显示。
  Future<void> _doPickImage(
    AntiqueEntity item,
    ImagePicker picker,
    ImageSource source,
  ) async {
    try {
      final photo = await picker.pickImage(source: source, maxWidth: 1024);
      if (photo == null || !mounted) return;

      // 保存到应用私有目录（和表单页同一个函数签名）
      final savedPath = await _saveImageToAppDir(photo);
      if (!mounted) return;

      _showCheckinDialog(item, savedPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片处理失败: $e')),
        );
        // 图片失败也允许纯文字打卡
        _showCheckinDialog(item, null);
      }
    }
  }

  void _showCheckinDialog(AntiqueEntity item, String? photoPath) {
    final noteCtrl = TextEditingController();
    final fileExists = photoPath != null && File(photoPath).existsSync();
    // 选中的打卡时间 — 在对话框外创建，避免每次 setState 重建重置为 now
    final selectedDate = ValueNotifier<DateTime>(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('打卡'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图片预览
                  if (fileExists)
                    SizedBox(
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, __) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text('图片加载失败',
                                style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ),
                        ),
                      ),
                    )
                  else if (photoPath != null && !fileExists)
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('图片文件不存在', style: TextStyle(fontSize: 12, color: Colors.orange)),
                      ),
                    )
                  else
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_border, color: Colors.pink, size: 20),
                            SizedBox(width: 6),
                            Text('无照片，纯文字记录', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // 打卡时间选择
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate.value,
                        firstDate: item.acquiredDate,
                        lastDate: now,
                        helpText: '选择打卡日期',
                      );
                      if (picked == null) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selectedDate.value),
                        helpText: '选择打卡时间',
                      );
                      if (time == null || !ctx.mounted) return;
                      setDialogState(() {
                        selectedDate.value = DateTime(
                          picked.year, picked.month, picked.day,
                          time.hour, time.minute,
                        );
                      });
                    },
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: selectedDate,
                      builder: (_, date, __) {
                        final y = (date.year % 100).toString().padLeft(2, '0');
                        final mo = date.month.toString().padLeft(2, '0');
                        final d = date.day.toString().padLeft(2, '0');
                        final h = date.hour.toString().padLeft(2, '0');
                        final mi = date.minute.toString().padLeft(2, '0');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Colors.teal),
                              const SizedBox(width: 8),
                              Text('$y/$mo/$d $h:$mi',
                                  style: const TextStyle(fontSize: 14)),
                              const Spacer(),
                              const Text('修改', style: TextStyle(fontSize: 12, color: Colors.teal)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 备注
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      hintText: '此刻的想法...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 3,
                    autofocus: photoPath == null || !fileExists,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  final note = noteCtrl.text.trim();
                  try {
                    final repo = await ref.read(antiqueRepositoryProvider.future);
                    await repo.addPattingLog(PattingLogEntity(
                      itemId: widget.itemId,
                      date: selectedDate.value,
                      durationMinutes: 0,
                      method: 'bare_hand',
                      note: note.isEmpty ? null : note,
                      photoPaths: (fileExists) ? [photoPath] : [],
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    _refreshPage();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('打卡成功'), duration: Duration(seconds: 1)),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('打卡失败: $e')),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.pink),
                child: const Text('打卡'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== 操作 =====

  /// 编辑打卡记录（修改备注和照片）
  Future<void> _editPattingLog(AntiqueEntity item, PattingLogEntity log) async {
    final noteCtrl = TextEditingController(text: log.note);
    // 当前照片路径（可被替换/删除）
    String? photoPath = log.photoPaths.isNotEmpty ? log.photoPaths.first : null;
    bool saved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('编辑记录'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图片预览
                  if (photoPath != null && File(photoPath!).existsSync())
                    SizedBox(
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(photoPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _photoPlaceholder(),
                        ),
                      ),
                    )
                  else
                    _photoPlaceholder(),
                  const SizedBox(height: 8),
                  // 拍照/选图/删除 按钮行
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('拍照', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1024);
                          if (photo != null && ctx.mounted) {
                            final p = await _saveImageToAppDir(photo);
                            setDialogState(() => photoPath = p);
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('相册', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final photo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
                          if (photo != null && ctx.mounted) {
                            final p = await _saveImageToAppDir(photo);
                            setDialogState(() => photoPath = p);
                          }
                        },
                      ),
                      if (photoPath != null)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          label: const Text('删除', style: TextStyle(fontSize: 12, color: Colors.red)),
                          onPressed: () => setDialogState(() => photoPath = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      hintText: '此刻的想法...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  saved = true;
                  Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (!saved || !mounted) return;
    try {
      final repo = await ref.read(antiqueRepositoryProvider.future);
      await repo.updatePattingLog(log.copyWith(
        note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        photoPaths: photoPath != null ? [photoPath!] : [],
      ));
      _refreshPage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已更新'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, color: Colors.grey, size: 28),
            SizedBox(height: 4),
            Text('无照片', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// 删除打卡记录
  Future<void> _deletePattingLog(PattingLogEntity log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条打卡记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repo = await ref.read(antiqueRepositoryProvider.future);
      await repo.deletePattingLog(log.id!);
      _refreshPage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _showComparePicker(BuildContext context, AntiqueEntity item) async {
    final logs = await _logsFuture;
    // 筛出有照片的记录
    final withPhotos = logs.where((l) => l.photoPaths.isNotEmpty).toList();
    if (withPhotos.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要至少两条带照片的打卡记录才能对比')),
        );
      }
      return;
    }
    // 按日期升序排列
    withPhotos.sort((a, b) => a.date.compareTo(b.date));

    String? leftKey;
    String? rightKey;
    // key = "${log.date.toIso8601String()}|${log.photoPaths.first}"
    for (final log in withPhotos) {
      final k = '${log.date.toIso8601String()}|${log.photoPaths.first}';
      leftKey ??= k;
      if (rightKey == null && k != leftKey) rightKey = k;
    }

    if (!mounted) return;
    // 弹选择+对比对话框（内嵌结果，不跳转新页面）
    await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _CompareDialog(
        logs: withPhotos,
        item: item,
        initialLeft: leftKey!,
        initialRight: rightKey!,
      ),
    );
  }

  /// 全屏对比结果
  void _handleAction(
    BuildContext context,
    AntiqueEntity item,
    String action,
  ) {
    switch (action) {
      case 'edit':
        context.push('/collection/${item.id}/edit');
        break;
      case 'delete':
        _confirmDelete(context, item);
        break;
      case 'compare':
        _showComparePicker(context, item);
        break;
    }
  }

  Future<void> _confirmDelete(BuildContext context, AntiqueEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
            '确定要删除「${item.name}」吗？\n所有图片、盘玩记录也将被删除。'),
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

// 对比弹窗直接内嵌结果，不再 push 新页面
class _CompareDialog extends StatefulWidget {
  final List<PattingLogEntity> logs;
  final AntiqueEntity item;
  final String initialLeft;
  final String initialRight;

  const _CompareDialog({
    required this.logs,
    required this.item,
    required this.initialLeft,
    required this.initialRight,
  });

  @override
  State<_CompareDialog> createState() => _CompareDialogState();
}

class _CompareDialogState extends State<_CompareDialog> {
  late String _leftKey;
  late String _rightKey;
  int _colorStyle = 1; // 默认暖木
  final _compareKey = GlobalKey();
  bool _savingImage = false;

  static const _styles = [
    {'name': '暗夜', 'bg': [Color(0xFF0D0D0D), Color(0xFF1A1A2E)], 'text': Colors.white70, 'subtext': Colors.white38, 'badgeBg': Colors.white24},
    {'name': '暖木', 'bg': [Color(0xFF2D1F15), Color(0xFF4A3728)], 'text': Color(0xFFE8D5C4), 'subtext': Color(0xFFB8A08E), 'badgeBg': Color(0x55FFFFFF)},
    {'name': '清新', 'bg': [Color(0xFF1B4332), Color(0xFF2D6A4F)], 'text': Color(0xFFD8F3DC), 'subtext': Color(0xFF95D5B2), 'badgeBg': Color(0x44FFFFFF)},
  ];

  PattingLogEntity? get _leftLog => _findLog(_leftKey);
  PattingLogEntity? get _rightLog => _findLog(_rightKey);

  PattingLogEntity? _findLog(String key) {
    for (final l in widget.logs) {
      if ('${l.date.toIso8601String()}|${l.photoPaths.first}' == key) return l;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _leftKey = widget.initialLeft;
    _rightKey = widget.initialRight;
  }

  @override
  Widget build(BuildContext context) {
    final s = _styles[_colorStyle];
    final colors = s['bg'] as List<Color>;
    final textColor = s['text'] as Color;
    final subtextColor = s['subtext'] as Color;
    final badgeBg = s['badgeBg'] as Color;
    final leftLog = _leftLog;
    final rightLog = _rightLog;

    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题 + 风格切换
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Text('时光对比', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _styles.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        label: Text(e.value['name'] as String, style: TextStyle(fontSize: 10, color: _colorStyle == e.key ? null : subtextColor.withValues(alpha: 0.7))),
                        selected: _colorStyle == e.key,
                        onSelected: (_) => setState(() => _colorStyle = e.key),
                        visualDensity: VisualDensity.compact,
                        selectedColor: Colors.teal.withValues(alpha: 0.3),
                      ),
                    )).toList()),
                  ),
                ],
              ),
            ),
            // 双图对比 (RepaintBoundary 用于截图保存整张对比图)
            if (leftLog != null && rightLog != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: RepaintBoundary(
                  key: _compareKey,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                    ),
                    child: SizedBox(
                    height: 300,
                    child: Row(
                      children: [
                        Expanded(child: _tile(leftLog, widget.item, textColor, subtextColor, badgeBg, true)),
                        Container(width: 1, color: badgeBg),
                        Expanded(child: _tile(rightLog, widget.item, textColor, subtextColor, badgeBg, false)),
                      ],
                    ),
                    ),
                  ),
                ),
              ),
            // 底部：照片选择 + 保存
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 左右选择器
                  Row(
                    children: [
                      Expanded(child: _photoPicker(true)),
                      const SizedBox(width: 8),
                      Expanded(child: _photoPicker(false)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _savingImage
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_alt, size: 18),
                          label: Text(_savingImage ? '保存中...' : '保存对比图'),
                          style: OutlinedButton.styleFrom(foregroundColor: textColor.withValues(alpha: 0.8)),
                          onPressed: _savingImage ? null : _saveCompareImage,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('关闭'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPicker(bool isLeft) {
    final entries = widget.logs.map((l) {
      final k = '${l.date.toIso8601String()}|${l.photoPaths.first}';
      final days = l.date.difference(widget.item.acquiredDate).inDays;
      return _CompareEntry(key: k, path: l.photoPaths.first, dayLabel: days == 0 ? '入手当天' : '第${days}天', dateStr: '', note: l.note);
    }).toList();
    final currentKey = isLeft ? _leftKey : _rightKey;
    final current = entries.where((e) => e.key == currentKey).firstOrNull;

    return GestureDetector(
      onTap: () => _showPhotoPicker(isLeft),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(File(current.path), width: 24, height: 24, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16)),
              ),
            const SizedBox(width: 4),
            Expanded(child: Text(current?.dayLabel ?? (isLeft ? '选择左侧' : '选择右侧'),
                style: const TextStyle(fontSize: 10, color: Colors.white70), maxLines: 1)),
            const Icon(Icons.unfold_more, size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showPhotoPicker(bool isLeft) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.logs.map((l) {
          final k = '${l.date.toIso8601String()}|${l.photoPaths.first}';
          final days = l.date.difference(widget.item.acquiredDate).inDays;
          final selected = (isLeft ? _leftKey : _rightKey) == k;
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: Image.file(File(l.photoPaths.first), width: 40, height: 40, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 24))),
            title: Text(days == 0 ? '入手当天' : '第$days天', style: TextStyle(fontWeight: selected ? FontWeight.bold : null)),
            subtitle: Text('${l.date.month}/${l.date.day} ${l.note ?? ''}', style: const TextStyle(fontSize: 11)),
            trailing: selected ? const Icon(Icons.check, color: Colors.teal) : null,
            onTap: () {
              setState(() {
                if (isLeft) _leftKey = k; else _rightKey = k;
              });
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _tile(PattingLogEntity log, AntiqueEntity item, Color textColor, Color subtextColor, Color badgeBg, bool isLeft) {
    final days = log.date.difference(item.acquiredDate).inDays;
    final color = isLeft ? Colors.tealAccent : Colors.orangeAccent;
    final y = (log.date.year % 100).toString().padLeft(2, '0');
    final mo = log.date.month.toString().padLeft(2, '0');
    final d = log.date.day.toString().padLeft(2, '0');

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: InteractiveViewer(maxScale: 4,
            child: Image.file(File(log.photoPaths.first), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 40))),
          ),
        ),
        Positioned(top: 4, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
              child: Text(isLeft ? '之前' : '之后', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        Positioned(bottom: 4, left: 4, right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
            child: Text('$y/$mo/$d  第${days}天', textAlign: TextAlign.center,
              style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
        if (log.note != null && log.note!.isNotEmpty)
          Positioned(bottom: 16, left: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: Text(log.note!, style: const TextStyle(color: Colors.white54, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
    );
  }

  Future<void> _saveCompareImage() async {
    if (_savingImage) return;
    setState(() => _savingImage = true);
    try {
      final boundary = _compareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取对比区域');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('图像编码失败');

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/compare_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '时光对比图');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingImage = false);
    }
  }
}

class _CompareEntry {
  final String key, path, dayLabel, dateStr;
  final String? note;
  const _CompareEntry({
    required this.key, required this.path,
    required this.dayLabel, required this.dateStr, this.note,
  });
}
