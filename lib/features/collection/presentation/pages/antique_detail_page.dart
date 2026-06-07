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
            Image.file(File(images[0]), fit: BoxFit.cover, width: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
            ),
            Positioned(bottom: 8, right: 8,
              child: _fullscreenButton(context, images[0]),
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
                  Image.file(File(images[index]), fit: BoxFit.cover, width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
                  ),
                  Positioned(bottom: 8, right: 8,
                    child: _fullscreenButton(context, images[index]),
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
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey, size: 20),
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

  /// 全屏查看图片
  void _showFullScreenImage(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 12,
                child: Material(
                  color: Colors.white24,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
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
    final deltaDays = (rightDays - leftDays).abs();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // 顶部导航
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(item.name, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // 双图并排
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _compareImageTile(leftLog.photoPaths.first, leftDays, leftLog.date, true)),
                      Container(width: 2, color: Colors.white24),
                      Expanded(child: _compareImageTile(rightLog.photoPaths.first, rightDays, rightLog.date, false)),
                    ],
                  ),
                ),
                // 底部信息条
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _compareStatBox('第${leftDays}天', leftLog.date),
                          Column(
                            children: [
                              const Text('VS', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
                              const SizedBox(height: 4),
                              Text('${deltaDays}天变化', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            ],
                          ),
                          _compareStatBox('第${rightDays}天', rightLog.date),
                        ],
                      ),
                      if (leftLog.note != null && leftLog.note!.isNotEmpty ||
                          rightLog.note != null && rightLog.note!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 8),
                        if (leftLog.note != null && leftLog.note!.isNotEmpty)
                          _compareNote(leftLog.note!, true),
                        if (rightLog.note != null && rightLog.note!.isNotEmpty) ...[
                          if (leftLog.note != null && leftLog.note!.isNotEmpty)
                            const SizedBox(height: 6),
                          _compareNote(rightLog.note!, false),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compareImageTile(String path, int days, DateTime date, bool isLeft) {
    final y = (date.year % 100).toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final color = isLeft ? Colors.tealAccent : Colors.orangeAccent;

    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(maxScale: 4, child: Image.file(File(path), fit: BoxFit.contain)),
        // 顶部标签
        Positioned(
          top: 8, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              isLeft ? '之前' : '之后',
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // 底部日期
        Positioned(
          bottom: 8, left: 8,
          child: Text('$y/$mo/$d', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _compareStatBox(String label, DateTime date) {
    final y = (date.year % 100).toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('$y/$mo/$d', style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }

  Widget _compareNote(String note, bool isLeft) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4, height: 4,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLeft ? Colors.tealAccent : Colors.orangeAccent,
          ),
        ),
        Expanded(
          child: Text(note, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
        ),
      ],
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

class _CompareSelectDialogState extends State<_CompareSelectDialog> {
  late String _leftKey;
  late String _rightKey;

  Map<String, _CompareEntry> _entries = {};

  @override
  void initState() {
    super.initState();
    _leftKey = widget.initialLeft;
    _rightKey = widget.initialRight;
    for (final log in widget.logs) {
      final k = '${log.date.toIso8601String()}|${log.photoPaths.first}';
      final days = log.date.difference(widget.item.acquiredDate).inDays;
      final y = (log.date.year % 100).toString().padLeft(2, '0');
      final mo = log.date.month.toString().padLeft(2, '0');
      final d = log.date.day.toString().padLeft(2, '0');
      final h = log.date.hour.toString().padLeft(2, '0');
      final mi = log.date.minute.toString().padLeft(2, '0');
      _entries[k] = _CompareEntry(
        key: k,
        path: log.photoPaths.first,
        dayLabel: days == 0 ? '入手当天' : '第${days}天',
        dateStr: '$y/$mo/$d $h:$mi',
        note: log.note,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries.values.toList();
    final leftEntry = _entries[_leftKey];
    final rightEntry = _entries[_rightKey];

    return AlertDialog(
      title: const Text('选择对比记录'),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 已选预览区
            if (leftEntry != null && rightEntry != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _miniCard(leftEntry, Colors.teal, '之前'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black87,
                            ),
                            child: const Center(
                              child: Text('VS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                        _miniCard(rightEntry, Colors.orange, '之后'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(builder: (_) {
                      final lDays = leftEntry.dayLabel == '入手当天' ? 0 : int.parse(leftEntry.dayLabel.replaceAll(RegExp(r'[^0-9]'), ''));
                      final rDays = rightEntry.dayLabel == '入手当天' ? 0 : int.parse(rightEntry.dayLabel.replaceAll(RegExp(r'[^0-9]'), ''));
                      return Text(
                        '${(rDays - lDays).abs()} 天的变化',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // 记录列表
            const Text('左右滑动切换选择', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  final isLeft = e.key == _leftKey;
                  final isRight = e.key == _rightKey;
                  final isSelected = isLeft || isRight;
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isLeft) { _leftKey = _rightKey; _rightKey = e.key; }
                      else if (isRight) { _rightKey = _leftKey; _leftKey = e.key; }
                      else { if (_leftKey == widget.initialLeft && _rightKey == widget.initialRight) { _leftKey = e.key; } else { _rightKey = e.key; } }
                    }),
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? (isLeft ? Colors.teal : Colors.orange)
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(isSelected ? 6 : 7)),
                              child: Image.file(File(e.path), fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: isLeft ? Colors.teal : (isRight ? Colors.orange : Colors.grey.shade100),
                            ),
                            child: Text(
                              e.dayLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '点左边设为「之前」  点右边设为「之后」',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _leftKey == _rightKey
              ? null
              : () => Navigator.pop(context, {'left': _leftKey, 'right': _rightKey}),
          icon: const Icon(Icons.compare_arrows, size: 18),
          label: const Text('开始对比'),
        ),
      ],
    );
  }

  Widget _miniCard(_CompareEntry e, Color color, String role) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(e.path), height: 50, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 50, color: Colors.grey.shade200),
              ),
            ),
            const SizedBox(height: 4),
            Text(e.dayLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            Text(e.dateStr, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _CompareEntry {
  final String key;
  final String path;
  final String dayLabel;
  final String dateStr;
  final String? note;

  const _CompareEntry({
    required this.key,
    required this.path,
    required this.dayLabel,
    required this.dateStr,
    this.note,
  });
}
