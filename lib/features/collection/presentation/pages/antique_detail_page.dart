/// 盘串详情页 — 时间线 + 盘玩打卡 + 情感记录。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';

class AntiqueDetailPage extends ConsumerStatefulWidget {
  final int itemId;

  const AntiqueDetailPage({super.key, required this.itemId});

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

  @override
  void initState() {
    super.initState();
    _itemFuture = _loadItem();
    _logsFuture = _loadLogs().then((logs) {
      _cachedLogs = logs;
      return logs;
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

  Widget _fullscreenButton(BuildContext context, String path) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showFullScreenImage(context, path),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fullscreen, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text('全屏', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
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
                ...item.categoryMetadata!.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(e.key,
                              style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                        Expanded(
                          child: Text(e.value,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                        ),
                      ],
                    ),
                  );
                }),
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

            return IntrinsicHeight(
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
                      color: Colors.grey.shade50,
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
    return dest.path;
  }

  /// 全屏查看图片 — 点击图片进入，再次点击任意位置退出
  void _showFullScreenImage(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
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
                          File(photoPath!),
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
                      photoPaths: (fileExists) ? [photoPath!] : [],
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
    // 弹选择+对比对话框
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _CompareSelectDialog(
        logs: withPhotos,
        item: item,
        initialLeft: leftKey!,
        initialRight: rightKey!,
      ),
    );

    if (result != null && mounted) {
      _showCompareResult(context, item, result['left']!, result['right']!, withPhotos);
    }
  }

  /// 全屏对比结果
  void _showCompareResult(
    BuildContext context,
    AntiqueEntity item,
    String leftKey,
    String rightKey,
    List<PattingLogEntity> logs,
  ) {
    PattingLogEntity? findLog(String key) {
      for (final l in logs) {
        if ('${l.date.toIso8601String()}|${l.photoPaths.first}' == key) return l;
      }
      return null;
    }

    final leftLog = findLog(leftKey);
    final rightLog = findLog(rightKey);
    if (leftLog == null || rightLog == null) return;

    final leftDays = leftLog.date.difference(item.acquiredDate).inDays;
    final rightDays = rightLog.date.difference(item.acquiredDate).inDays;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _CompareResultPage(
          leftLog: leftLog,
          rightLog: rightLog,
          item: item,
          leftDays: leftDays,
          rightDays: rightDays,
        ),
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

// ===== 对比结果页 =====

class _CompareResultPage extends StatefulWidget {
  final PattingLogEntity leftLog;
  final PattingLogEntity rightLog;
  final AntiqueEntity item;
  final int leftDays;
  final int rightDays;

  const _CompareResultPage({
    required this.leftLog, required this.rightLog,
    required this.item, required this.leftDays, required this.rightDays,
  });

  @override
  State<_CompareResultPage> createState() => _CompareResultPageState();
}

class _CompareResultPageState extends State<_CompareResultPage> {
  int _styleIndex = 0;
  static const _styles = [
    {'name': '暗夜', 'colors': [Color(0xFF0D0D0D), Color(0xFF1A1A2E)]},
    {'name': '暖木', 'colors': [Color(0xFF2D1F15), Color(0xFF4A3728)]},
    {'name': '素白', 'colors': [Color(0xFFF5F0EB), Color(0xFFE8E0D5)]},
  ];

  @override
  Widget build(BuildContext context) {
    final l = widget.leftLog;
    final r = widget.rightLog;
    final s = _styles[_styleIndex];
    final colors = s['colors'] as List<Color>;
    final isDark = _styleIndex != 2;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航 + 风格切换
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 12, 2),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54, size: 18),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // 风格选择 chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _styles.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(e.value['name'] as String, style: TextStyle(fontSize: 11, color: _styleIndex == e.key ? null : (isDark ? Colors.white54 : Colors.black54))),
                        selected: _styleIndex == e.key,
                        onSelected: (_) => setState(() => _styleIndex = e.key),
                        visualDensity: VisualDensity.compact,
                        selectedColor: isDark ? Colors.teal.withValues(alpha: 0.4) : Colors.teal.withValues(alpha: 0.15),
                      ),
                    )).toList()),
                  ),
                  const Spacer(),
                  Text(widget.item.name, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            // 双图对比区
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(child: _compareImageTile(l.photoPaths.first, widget.leftDays, l.date, true, l.note)),
                    Container(width: 1, color: isDark ? Colors.white30 : Colors.black26),
                    Expanded(child: _compareImageTile(r.photoPaths.first, widget.rightDays, r.date, false, r.note)),
                  ],
                ),
              ),
            ),
            // 底部信息 + 保存
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                children: [
                  Expanded(child: _compareDayBadge(widget.leftDays, l.date, isDark)),
                  const Text(' vs ', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(child: _compareDayBadge(widget.rightDays, r.date, isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareDayBadge(int days, DateTime date, bool isDark) {
    final y = (date.year % 100).toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return Column(
      children: [
        Text(days == 0 ? '入手当天' : '第$days天',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
        Text('$y/$mo/$d', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 11)),
      ],
    );
  }

  static Widget _compareImageTile(String path, int days, DateTime date, bool isLeft, String? note) {
    final y = (date.year % 100).toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final color = isLeft ? Colors.tealAccent : Colors.orangeAccent;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 4,
            child: Image.file(File(path), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 40))),
          ),
        ),
        Positioned(top: 6, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(isLeft ? '之前' : '之后', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        if (note != null && note.isNotEmpty)
          Positioned(bottom: 6, left: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(note, style: const TextStyle(color: Colors.white54, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
    );
  }
}

// ===== 对比选择对话框 =====

class _CompareSelectDialog extends StatefulWidget {
  final List<PattingLogEntity> logs;
  final AntiqueEntity item;
  final String initialLeft;
  final String initialRight;

  const _CompareSelectDialog({
    required this.logs,
    required this.item,
    required this.initialLeft,
    required this.initialRight,
  });

  @override
  State<_CompareSelectDialog> createState() => _CompareSelectDialogState();
}

class _CompareSelectDialogState extends State<_CompareSelectDialog>
    with SingleTickerProviderStateMixin {
  late String _leftKey;
  late String _rightKey;
  Map<String, _CompareEntry> _entries = {};
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _leftKey = widget.initialLeft;
    _rightKey = widget.initialRight;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    for (final log in widget.logs) {
      final k = '${log.date.toIso8601String()}|${log.photoPaths.first}';
      final days = log.date.difference(widget.item.acquiredDate).inDays;
      final y = (log.date.year % 100).toString().padLeft(2, '0');
      final mo = log.date.month.toString().padLeft(2, '0');
      final d = log.date.day.toString().padLeft(2, '0');
      final h = log.date.hour.toString().padLeft(2, '0');
      final mi = log.date.minute.toString().padLeft(2, '0');
      _entries[k] = _CompareEntry(
        key: k, path: log.photoPaths.first,
        dayLabel: days == 0 ? '入手当天' : '第${days}天',
        dateStr: '$y/$mo/$d $h:$mi', note: log.note,
      );
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries.values.toList();
    final leftEntry = _entries[_leftKey];
    final rightEntry = _entries[_rightKey];
    final lDays = leftEntry?.dayLabel == '入手当天' ? 0 : int.tryParse(leftEntry?.dayLabel.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    final rDays = rightEntry?.dayLabel == '入手当天' ? 0 : int.tryParse(rightEntry?.dayLabel.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部标题
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 20,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  const Text('时光对比',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.close, color: Colors.white54, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            // 预览区
            if (leftEntry != null && rightEntry != null)
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) => Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.tealAccent.withValues(alpha: 0.05 + _pulseCtrl.value * 0.03),
                        Colors.orangeAccent.withValues(alpha: 0.05 + _pulseCtrl.value * 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _previewCard(leftEntry, const Color(0xFF00BCD4), '左')),
                          const SizedBox(width: 16),
                          Expanded(child: _previewCard(rightEntry, const Color(0xFFFF9800), '右')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${(rDays - lDays).abs()} 天间距',
                          style: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // 记录卡片选择器
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _sectionDot(const Color(0xFF00BCD4)),
                  const SizedBox(width: 6),
                  const Text('轻触选择', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                  const Spacer(),
                  _sectionDot(const Color(0xFFFF9800)),
                  const SizedBox(width: 6),
                  const Text('再次轻触交换', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  final isLeft = e.key == _leftKey;
                  final isRight = e.key == _rightKey;
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isLeft) { _leftKey = _rightKey; _rightKey = e.key; }
                      else if (isRight) { _rightKey = _leftKey; _leftKey = e.key; }
                      else {
                        if (_leftKey == widget.initialLeft && _rightKey == widget.initialRight) { _leftKey = e.key; }
                        else { _rightKey = e.key; }
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLeft ? const Color(0xFF00BCD4)
                               : isRight ? const Color(0xFFFF9800)
                               : Colors.white12,
                          width: isLeft || isRight ? 2 : 1),
                        boxShadow: (isLeft || isRight) ? [
                          BoxShadow(color: (isLeft ? Colors.tealAccent : Colors.orangeAccent).withValues(alpha: 0.2), blurRadius: 8),
                        ] : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(e.path), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: Colors.white10)),
                            // 底部时间标签
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black54],
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(e.dayLabel, textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                        color: (isLeft || isRight) ? Colors.white : Colors.white60)),
                                    Text(e.dateStr, textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 8, color: (isLeft || isRight) ? Colors.white70 : Colors.white38)),
                                  ],
                                ),
                              ),
                            ),
                            // 选中角标
                            if (isLeft)
                              Positioned(top: 3, left: 3,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00BCD4), shape: BoxShape.circle),
                                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 10),
                                ),
                              ),
                            if (isRight)
                              Positioned(top: 3, right: 3,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF9800), shape: BoxShape.circle),
                                  child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // 操作按钮
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white38,
                        side: const BorderSide(color: Colors.white12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('取消', style: TextStyle(letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _leftKey == _rightKey ? null
                          : () => Navigator.pop(context, {'left': _leftKey, 'right': _rightKey}),
                      icon: const Icon(Icons.compare_arrows, size: 20),
                      label: const Text('对比', style: TextStyle(letterSpacing: 1)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard(_CompareEntry e, Color color, String side) {
    return Column(
      children: [
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.file(File(e.path), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.white10)),
          ),
        ),
        const SizedBox(height: 8),
        Text(e.dayLabel, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(e.dateStr, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _sectionDot(Color color) {
    return Container(width: 6, height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
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
