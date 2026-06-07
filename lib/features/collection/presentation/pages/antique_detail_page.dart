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

  @override
  void initState() {
    super.initState();
    _itemFuture = _loadItem();
    _logsFuture = _loadLogs();
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
      _logsFuture = _loadLogs();
    });
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
                // 图片轮播
                _buildImageCarousel(item),
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

  Widget _buildImageCarousel(AntiqueEntity item) {
    if (item.imagePaths.isEmpty) {
      return Container(
        height: 260,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.diamond_outlined, size: 64, color: Colors.grey),
        ),
      );
    }

    if (item.imagePaths.length == 1) {
      return SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(item.imagePaths[0]), fit: BoxFit.cover, width: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
            ),
            Positioned(bottom: 8, right: 8,
              child: _fullscreenButton(context, item.imagePaths[0]),
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
            itemCount: item.imagePaths.length,
            onPageChanged: (i) => _currentPage.value = i,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(item.imagePaths[index]), fit: BoxFit.cover, width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
                  ),
                  Positioned(bottom: 8, right: 8,
                    child: _fullscreenButton(context, item.imagePaths[index]),
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
            children: List.generate(item.imagePaths.length, (i) => Container(
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
          builder: (_, page, __) => Text('${page + 1} / ${item.imagePaths.length}',
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
                                Icon(Icons.favorite,
                                    size: 14, color: Colors.pink.shade200),
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

  /// 选择两个打卡记录进行对比
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
    final leftLabel = leftDays == 0 ? '入手当天' : '入手${leftDays}天';
    final rightLabel = rightDays == 0 ? '入手当天' : '入手${rightDays}天';

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('对比', style: TextStyle(color: Colors.white, fontSize: 16)),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // 上图：左右并排图片
              Expanded(
                child: Row(
                  children: [
                    // 左侧
                    Expanded(
                      child: _compareImageTile(leftLog.photoPaths.first, leftLabel, leftLog.date),
                    ),
                    // 分割线
                    Container(width: 1, color: Colors.white30),
                    // 右侧
                    Expanded(
                      child: _compareImageTile(rightLog.photoPaths.first, rightLabel, rightLog.date),
                    ),
                  ],
                ),
              ),
              // 下图：信息对比卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _compareStatBox('${leftDays}天', leftLabel, Colors.teal),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.grey)),
                        ),
                        Expanded(
                          child: _compareStatBox('${rightDays}天', rightLabel, Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 盘玩天数差值
                    Center(
                      child: Text(
                        '${(rightDays - leftDays).abs()} 天的变化',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (leftLog.note != null && leftLog.note!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _compareNoteRow('当时', leftLabel, leftLog.note!),
                    ],
                    if (rightLog.note != null && rightLog.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _compareNoteRow('现在', rightLabel, rightLog.note!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compareImageTile(String path, String label, DateTime date) {
    final y = (date.year % 100).toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');

    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          maxScale: 3,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
        Positioned(
          bottom: 8, left: 8, right: 8,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 2),
              Text('$y/$mo/$d $h:$mi', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compareStatBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _compareNoteRow(String prefix, String label, String note) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$prefix ', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(note, style: const TextStyle(fontSize: 13)),
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

  Map<String, String> _keyMap = {};

  @override
  void initState() {
    super.initState();
    _leftKey = widget.initialLeft;
    _rightKey = widget.initialRight;
    for (final log in widget.logs) {
      final k = '${log.date.toIso8601String()}|${log.photoPaths.first}';
      final days = log.date.difference(widget.item.acquiredDate).inDays;
      final label = days == 0 ? '入手当天' : '入手${days}天';
      final y = (log.date.year % 100).toString().padLeft(2, '0');
      final mo = log.date.month.toString().padLeft(2, '0');
      final d = log.date.day.toString().padLeft(2, '0');
      final h = log.date.hour.toString().padLeft(2, '0');
      final mi = log.date.minute.toString().padLeft(2, '0');
      _keyMap[k] = '$label  $y/$mo/$d $h:$mi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftLabel = _keyMap[_leftKey] ?? '';
    final rightLabel = _keyMap[_rightKey] ?? '';

    return AlertDialog(
      title: const Text('选择对比记录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 左记录选择
          DropdownButtonFormField<String>(
            value: _leftKey,
            decoration: const InputDecoration(
              labelText: '左侧（之前）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _keyMap.entries.map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _leftKey = v);
            },
          ),
          const SizedBox(height: 12),
          // 分割
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          // 右记录选择
          DropdownButtonFormField<String>(
            value: _rightKey,
            decoration: const InputDecoration(
              labelText: '右侧（之后）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _keyMap.entries.map((e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _rightKey = v);
            },
          ),
          const SizedBox(height: 16),
          // 预览 — 两张小图并排
          if (_leftKey != _rightKey)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 120,
                child: Row(
                  children: [
                    Expanded(
                      child: Image.file(
                        File(_leftKey.split('|').last),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                      ),
                    ),
                    Container(width: 2, color: Colors.white),
                    Expanded(
                      child: Image.file(
                        File(_rightKey.split('|').last),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_leftKey != _rightKey)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(leftLabel, style: const TextStyle(fontSize: 11, color: Colors.teal)),
            ),
          if (_leftKey != _rightKey)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(rightLabel, style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _leftKey == _rightKey
              ? null
              : () => Navigator.pop(context, {'left': _leftKey, 'right': _rightKey}),
          child: const Text('开始对比'),
        ),
      ],
    );
  }
}
