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

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../../../core/utils/image_utils.dart';
import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';
import '../widgets/resolved_image.dart';

class AntiqueDetailPage extends ConsumerStatefulWidget {
  final int itemId;
  final int? highlightLogId;

  const AntiqueDetailPage({
    super.key,
    required this.itemId,
    this.highlightLogId,
  });

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
          return _buildMissingItemPage();
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildImageCarousel(item, _getBannerImages(item)),
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInfoCard(item),
                          if (item.categoryMetadata != null &&
                              item.categoryMetadata!.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _buildMetadataSection(item),
                          ],
                          const SizedBox(height: 18),
                          _buildPattingHeatmap(item),
                          const SizedBox(height: 18),
                          _buildPattingTimeline(item),
                          const SizedBox(height: 24),
                          _buildBottomActions(item),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SafeArea(child: _buildTopOverlay(context, item)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMissingItemPage() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: _leaveMissingItemPage,
                icon: const Icon(Icons.chevron_left),
                label: const Text('返回'),
              ),
            ),
            const SizedBox(height: 16),
            AppSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.diamond_outlined,
                      color: AppColors.primaryDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '宝贝不存在',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '这件藏品可能已经删除，或当前数据库中没有对应记录。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => context.go(RouteNames.collectionList),
                    icon: const Icon(Icons.grid_view),
                    label: const Text('回到盘串'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _leaveMissingItemPage() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(RouteNames.collectionList);
  }

  Widget _buildTopOverlay(BuildContext context, AntiqueEntity item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _HeroIconButton(
            tooltip: '返回',
            icon: Icons.chevron_left,
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          _HeroIconButton(
            tooltip: '编辑',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/collection/${item.id}/edit'),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(999),
            ),
            child: PopupMenuButton<String>(
              tooltip: '更多',
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              color: AppColors.card,
              onSelected: (value) => _handleAction(context, item, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑信息')),
                const PopupMenuItem(value: 'compare', child: Text('时光对比')),
                const PopupMenuItem(value: 'delete', child: Text('删除藏品')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(AntiqueEntity item, List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 320,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: const Center(
          child: Icon(Icons.diamond_outlined, size: 70, color: Colors.white70),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => _currentPage.value = i,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showFullScreenImage(context, images[index]),
                onLongPress: () => _showImageActions(context, images[index]),
                child: ResolvedImage(
                  path: images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: Container(
                    color: AppColors.primaryLight,
                    child: const Center(child: Icon(Icons.image)),
                  ),
                  error: Container(
                    color: AppColors.primaryLight,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x99000000),
                ],
                stops: [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 42,
            child: ValueListenableBuilder<int>(
              valueListenable: _currentPage,
              builder: (_, page, __) {
                final current = page >= images.length
                    ? images.length - 1
                    : page;
                return _buildHeroSourceTag(images[current]);
              },
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: 16,
              bottom: 46,
              child: _buildHeroDots(images.length),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AntiqueEntity item) {
    final daysOwned = DateTime.now().difference(item.acquiredDate).inDays;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<List<PattingLogEntity>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          final logs =
              snapshot.data ?? _cachedLogs ?? const <PattingLogEntity>[];
          final totalMinutes = logs.fold<int>(
            0,
            (sum, log) => sum + log.durationMinutes,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppPill(
                    label: item.category,
                    color: _categoryColor(item.category),
                    icon: _categoryIcon(item.category),
                    isFilled: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '入手日期：${_formatDate(item.acquiredDate)}'
                '${item.sourceSeller == null ? '' : ' · 来源：${item.sourceSeller}'}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              _buildMetricStrip(
                daysOwned: daysOwned,
                totalMinutes: totalMinutes,
                price: item.acquiredPrice,
              ),
              const SizedBox(height: 16),
              _infoRow(
                '品相',
                item.conditionLabel,
                icon: Icons.verified_outlined,
                valueColor: _conditionColor(item.condition),
              ),
              if (item.subtype != null && item.subtype!.isNotEmpty)
                _infoRow('细分', item.subtype!, icon: Icons.sell_outlined),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const Divider(height: 20),
                const Text(
                  '备注',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.notes!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroSourceTag(String path) {
    final isLatestLog =
        _cachedLogs != null &&
        _cachedLogs!.any((l) => l.photoPaths.contains(path));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLatestLog ? Icons.history : Icons.photo_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            isLatestLog ? '最新打卡' : '藏品照片',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroDots(int count) {
    return ValueListenableBuilder<int>(
      valueListenable: _currentPage,
      builder: (_, page, __) {
        return Row(
          children: List.generate(count, (index) {
            final selected = index == page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 18 : 7,
              height: 7,
              margin: const EdgeInsets.only(left: 5),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white54,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMetricStrip({
    required int daysOwned,
    required int totalMinutes,
    required double? price,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _buildMetricCell('陪伴天数', '$daysOwned'),
          const _MetricDivider(),
          _buildMetricCell('总时长', '${totalMinutes}m', color: AppColors.primary),
          const _MetricDivider(),
          _buildMetricCell(
            '入手价',
            price == null ? '未记录' : '¥${price.toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(AntiqueEntity item) {
    final metadata = item.categoryMetadata;
    if (metadata == null || metadata.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle(title: '参数特征', padding: EdgeInsets.zero),
        const SizedBox(height: 8),
        AppSurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.category == '核桃')
                _buildWalnutSpecTable(metadata)
              else
                _buildSingleSpecRows(metadata),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalnutSpecTable(Map<String, String> metadata) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  '参数',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '左核',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '右核',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          ...metadata.entries.map((entry) {
            final parts = entry.value.split(',');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        parts.isNotEmpty ? parts[0].trim() : '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        parts.length > 1 ? parts[1].trim() : '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSingleSpecRows(Map<String, String> metadata) {
    return Column(
      children: metadata.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                entry.value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    Color? valueColor,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: valueColor ?? AppColors.muted),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.ink,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(AntiqueEntity item) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push('/collection/${item.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _addPattingCheckin(item),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('拍照打卡'),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  IconData _categoryIcon(String category) {
    switch (category) {
      case '核桃':
        return Icons.circle_outlined;
      case '手串':
      case '长串':
        return Icons.blur_circular_outlined;
      case '把件':
        return Icons.category_outlined;
      default:
        return Icons.label_outline;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case '核桃':
        return AppColors.primary;
      case '手串':
        return AppColors.green;
      case '长串':
        return AppColors.gold;
      case '把件':
        return AppColors.blue;
      default:
        return AppColors.primary;
    }
  }

  Color _conditionColor(AntiqueCondition condition) {
    switch (condition) {
      case AntiqueCondition.perfect:
        return AppColors.green;
      case AntiqueCondition.good:
        return AppColors.primary;
      case AntiqueCondition.fair:
        return AppColors.orange;
      case AntiqueCondition.poor:
        return AppColors.red;
    }
  }

  // ===== 本月盘玩热力图 =====

  Widget _buildPattingHeatmap(AntiqueEntity item) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                size: 18,
                color: AppColors.orange,
              ),
              SizedBox(width: 6),
              Text(
                '本月打卡热力图',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<PattingLogEntity>>(
            future: _logsFuture,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? <PattingLogEntity>[];
              return _buildHeatmapGrid(logs);
            },
          ),
        ],
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

    // 按打卡次数分色：1次浅色，2次中色，3次+深色
    final pattingCount = <int, int>{};
    for (final log in logs) {
      if (log.date.year == now.year && log.date.month == now.month) {
        pattingCount[log.date.day] = (pattingCount[log.date.day] ?? 0) + 1;
      }
    }

    Color heatColor(int count) {
      if (count == 0) return AppColors.line.withValues(alpha: 0.42);
      if (count == 1) return AppColors.primaryLight;
      if (count <= 3) return AppColors.primary.withValues(alpha: 0.62);
      return AppColors.primaryDark;
    }

    return Column(
      children: [
        // 星期标签
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日'].map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
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
                    color: heatColor(count),
                    borderRadius: BorderRadius.circular(4),
                    border: isToday
                        ? Border.all(color: AppColors.primaryDark, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.bold : null,
                      color: count >= 3 ? Colors.white : AppColors.ink,
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
            _heatLegend(AppColors.line.withValues(alpha: 0.42), '无'),
            const SizedBox(width: 8),
            _heatLegend(AppColors.primaryLight, '1次'),
            const SizedBox(width: 8),
            _heatLegend(AppColors.primary.withValues(alpha: 0.62), '2-3次'),
            const SizedBox(width: 8),
            _heatLegend(AppColors.primaryDark, '3次+'),
          ],
        ),
      ],
    );
  }

  Widget _heatLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.muted),
        ),
      ],
    );
  }

  // ===== 盘玩打卡时间线 =====

  Widget _buildPattingTimeline(AntiqueEntity item) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.timeline, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      '成长时间轴',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showComparePicker(context, item),
                icon: const Icon(Icons.compare_arrows, size: 18),
                label: const Text('时光对比'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimelineList(item),
        ],
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
                  Icon(
                    Icons.pan_tool_outlined,
                    size: 40,
                    color: AppColors.muted,
                  ),
                  SizedBox(height: 8),
                  Text('还没有盘玩记录', style: TextStyle(color: AppColors.muted)),
                  SizedBox(height: 4),
                  Text(
                    '点击下方按钮打卡',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
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
            final daysSinceAcquisition = log.date
                .difference(item.acquiredDate)
                .inDays;
            final dayLabel = daysSinceAcquisition == 0
                ? '入手当天'
                : '第$daysSinceAcquisition天';
            // 日期时间：26/03/05 16:38
            final y = (log.date.year % 100).toString().padLeft(2, '0');
            final m = log.date.month.toString().padLeft(2, '0');
            final d = log.date.day.toString().padLeft(2, '0');
            final time =
                '${log.date.hour.toString().padLeft(2, '0')}:${log.date.minute.toString().padLeft(2, '0')}';
            final dateTimeStr = '$y/$m/$d $time';
            final hasPhoto = log.photoPaths.isNotEmpty;
            final isHighlighted =
                _highlightLogId != null && log.id == _highlightLogId;

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
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
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
                          color: isFirst
                              ? AppColors.primary
                              : AppColors.primaryLight,
                          border: Border.all(
                            color: AppColors.primaryLight,
                            width: 3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(width: 2, color: AppColors.line),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 内容卡片
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isHighlighted && _isHighlighting
                            ? AppColors.gold.withValues(alpha: 0.18)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isHighlighted && _isHighlighting
                              ? AppColors.gold
                              : AppColors.line,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dateTimeStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const Spacer(),
                                // 编辑按钮
                                GestureDetector(
                                  onTap: () => _editPattingLog(item, log),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                                // 删除按钮
                                GestureDetector(
                                  onTap: () => _deletePattingLog(log),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 2),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (log.note != null && log.note!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  log.note!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            if (hasPhoto) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: log.photoPaths.map((path) {
                                  return GestureDetector(
                                    onTap: () =>
                                        _showFullScreenImage(context, path),
                                    onLongPress: () =>
                                        _showImageActions(context, path),
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.line,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: ResolvedImage(
                                          path: path,
                                          fit: BoxFit.cover,
                                          placeholder: const Icon(
                                            Icons.image,
                                            color: AppColors.muted,
                                            size: 28,
                                          ),
                                          error: const Icon(
                                            Icons.broken_image,
                                            color: AppColors.muted,
                                            size: 28,
                                          ),
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
                  child: ResolvedImage(path: path, fit: BoxFit.contain),
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
      final resolved = await resolveImageFile(path);
      final file = XFile(resolved.path);
      await Share.shareXFiles([file], text: '分享图片');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失败: $e')));
      }
    }
  }

  /// 保存图片到系统相册
  Future<void> _saveImageToGallery(BuildContext context, String path) async {
    try {
      final file = await resolveImageFile(path);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('图片文件不存在')));
        }
        return;
      }
      final bytes = await file.readAsBytes();
      // gal 需要先写入临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/temp_save_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
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
              child: Text(
                '记录此刻',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('图片处理失败: $e')));
        // 图片失败也允许纯文字打卡
        _showCheckinDialog(item, null);
      }
    }
  }

  void _showCheckinDialog(AntiqueEntity item, String? photoPath) {
    final noteCtrl = TextEditingController();
    final hasPhoto = photoPath != null;
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
                  if (hasPhoto)
                    SizedBox(
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ResolvedImage(
                          path: photoPath,
                          fit: BoxFit.cover,
                          error: Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Text(
                              '图片加载失败',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
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
                            Icon(
                              Icons.favorite_border,
                              color: Colors.pink,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '无照片，纯文字记录',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
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
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$y/$mo/$d $h:$mi',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const Spacer(),
                              const Text(
                                '修改',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                ),
                              ),
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
                    autofocus: !hasPhoto,
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
                    final repo = await ref.read(
                      antiqueRepositoryProvider.future,
                    );
                    await repo.addPattingLog(
                      PattingLogEntity(
                        itemId: widget.itemId,
                        date: selectedDate.value,
                        durationMinutes: 0,
                        method: 'bare_hand',
                        note: note.isEmpty ? null : note,
                        photoPaths: hasPhoto ? [photoPath] : [],
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _refreshPage();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('打卡成功'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('打卡失败: $e')));
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
                  if (photoPath != null)
                    SizedBox(
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ResolvedImage(
                          path: photoPath!,
                          fit: BoxFit.cover,
                          placeholder: _photoPlaceholder(),
                          error: _photoPlaceholder(),
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
                          final photo = await ImagePicker().pickImage(
                            source: ImageSource.camera,
                            maxWidth: 1024,
                          );
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
                          final photo = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1024,
                          );
                          if (photo != null && ctx.mounted) {
                            final p = await _saveImageToAppDir(photo);
                            setDialogState(() => photoPath = p);
                          }
                        },
                      ),
                      if (photoPath != null)
                        TextButton.icon(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: const Text(
                            '删除',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                          onPressed: () =>
                              setDialogState(() => photoPath = null),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
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
      await repo.updatePattingLog(
        log.copyWith(
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          photoPaths: photoPath != null ? [photoPath!] : [],
        ),
      );
      _refreshPage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已更新'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _showComparePicker(
    BuildContext context,
    AntiqueEntity item,
  ) async {
    final logs = await _logsFuture;
    // 筛出有照片的记录
    final withPhotos = logs.where((l) => l.photoPaths.isNotEmpty).toList();
    if (withPhotos.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要至少两条带照片的打卡记录才能对比')));
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
  void _handleAction(BuildContext context, AntiqueEntity item, String action) {
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
        content: Text('确定要删除「${item.name}」吗？\n所有图片、盘玩记录也将被删除。'),
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

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.ink.withValues(alpha: 0.34),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: AppColors.line);
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
    {
      'name': '暗夜',
      'bg': [Color(0xFF0D0D0D), Color(0xFF1A1A2E)],
      'text': Colors.white70,
      'subtext': Colors.white38,
      'badgeBg': Colors.white24,
    },
    {
      'name': '暖木',
      'bg': [Color(0xFF2D1F15), Color(0xFF4A3728)],
      'text': Color(0xFFE8D5C4),
      'subtext': Color(0xFFB8A08E),
      'badgeBg': Color(0x55FFFFFF),
    },
    {
      'name': '清新',
      'bg': [Color(0xFF1B4332), Color(0xFF2D6A4F)],
      'text': Color(0xFFD8F3DC),
      'subtext': Color(0xFF95D5B2),
      'badgeBg': Color(0x44FFFFFF),
    },
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题 + 风格切换
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Text(
                    '时光对比',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _styles
                          .asMap()
                          .entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ChoiceChip(
                                label: Text(
                                  e.value['name'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _colorStyle == e.key
                                        ? null
                                        : subtextColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                selected: _colorStyle == e.key,
                                onSelected: (_) =>
                                    setState(() => _colorStyle = e.key),
                                visualDensity: VisualDensity.compact,
                                selectedColor: Colors.teal.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
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
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: colors,
                      ),
                    ),
                    child: SizedBox(
                      height: 300,
                      child: Row(
                        children: [
                          Expanded(
                            child: _tile(
                              leftLog,
                              widget.item,
                              textColor,
                              subtextColor,
                              badgeBg,
                              true,
                            ),
                          ),
                          Container(width: 1, color: badgeBg),
                          Expanded(
                            child: _tile(
                              rightLog,
                              widget.item,
                              textColor,
                              subtextColor,
                              badgeBg,
                              false,
                            ),
                          ),
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
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_alt, size: 18),
                          label: Text(_savingImage ? '保存中...' : '保存对比图'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor.withValues(alpha: 0.8),
                          ),
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
      return _CompareEntry(
        key: k,
        path: l.photoPaths.first,
        dayLabel: days == 0 ? '入手当天' : '第${days}天',
        dateStr: '',
        note: l.note,
      );
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
                child: ResolvedImage(
                  path: current.path,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  placeholder: const Icon(Icons.image, size: 16),
                  error: const Icon(Icons.image, size: 16),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                current?.dayLabel ?? (isLeft ? '选择左侧' : '选择右侧'),
                style: const TextStyle(fontSize: 10, color: Colors.white70),
                maxLines: 1,
              ),
            ),
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
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ResolvedImage(
                path: l.photoPaths.first,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: const Icon(Icons.image, size: 24),
                error: const Icon(Icons.image, size: 24),
              ),
            ),
            title: Text(
              days == 0 ? '入手当天' : '第$days天',
              style: TextStyle(fontWeight: selected ? FontWeight.bold : null),
            ),
            subtitle: Text(
              '${l.date.month}/${l.date.day} ${l.note ?? ''}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: selected
                ? const Icon(Icons.check, color: Colors.teal)
                : null,
            onTap: () {
              setState(() {
                if (isLeft)
                  _leftKey = k;
                else
                  _rightKey = k;
              });
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _tile(
    PattingLogEntity log,
    AntiqueEntity item,
    Color textColor,
    Color subtextColor,
    Color badgeBg,
    bool isLeft,
  ) {
    final days = log.date.difference(item.acquiredDate).inDays;
    final color = isLeft ? Colors.tealAccent : Colors.orangeAccent;
    final y = (log.date.year % 100).toString().padLeft(2, '0');
    final mo = log.date.month.toString().padLeft(2, '0');
    final d = log.date.day.toString().padLeft(2, '0');

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 4,
            child: ResolvedImage(
              path: log.photoPaths.first,
              fit: BoxFit.contain,
              error: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isLeft ? '之前' : '之后',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$y/$mo/$d  第${days}天',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        if (log.note != null && log.note!.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.note!,
                style: const TextStyle(color: Colors.white54, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _saveCompareImage() async {
    if (_savingImage) return;
    setState(() => _savingImage = true);
    try {
      final boundary =
          _compareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取对比区域');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('图像编码失败');

      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/compare_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '时光对比图');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
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
    required this.key,
    required this.path,
    required this.dayLabel,
    required this.dateStr,
    this.note,
  });
}
