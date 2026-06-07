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
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.favorite),
            label: const Text('盘玩打卡'),
            onPressed: () => _addPattingCheckin(item),
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

    return SizedBox(
      height: 260,
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
      future: ref
          .read(antiqueRepositoryProvider.future)
          .then((r) => r.getPattingLogs(widget.itemId)),
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
        // 按日期降序排列
        final sorted = List<PattingLogEntity>.from(logs)
          ..sort((a, b) => b.date.compareTo(a.date));

        return Column(
          children: sorted.map((log) {
            // 格式化日期显示
            final dateStr =
                '${log.date.month}月${log.date.day}日 ${log.date.hour.toString().padLeft(2, '0')}:${log.date.minute.toString().padLeft(2, '0')}';
            final hasPhoto = log.photoPaths.isNotEmpty;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 时间线左侧
                  SizedBox(
                    width: 60,
                    child: Column(
                      children: [
                        Text(
                          '${log.date.month}/${log.date.day}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                          color: Colors.teal,
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
                                  dateStr,
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

  // ===== 盘玩打卡（修复拍照后灰屏、打卡后刷新） =====

  /// 将 XFile 保存到应用私有目录（解决 content:// URI 无法被 File() 读取）
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
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
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
              child: Text('记录此刻', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('拍照'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024);
                  if (photo != null && mounted) {
                    // 先保存到本地，再弹对话框（避免对话框内异步加载卡死）
                    final savedPath = await _saveImageToAppDir(photo);
                    if (mounted) _showCheckinDialog(item, savedPath);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('从相册选择'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final photo = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
                  if (photo != null && mounted) {
                    final savedPath = await _saveImageToAppDir(photo);
                    if (mounted) _showCheckinDialog(item, savedPath);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择失败: $e')));
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCheckinDialog(AntiqueEntity item, String? photoPath) {
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('盘玩打卡'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图片预览 — 不再异步加载，传入时已保存好
              if (photoPath != null && photoPath.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(photoPath),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: const Center(child: Text('图片加载失败')),
                    ),
                  ),
                )
              else
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border, color: Colors.pink, size: 28),
                        SizedBox(height: 4),
                        Text('无照片，纯文字记录', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
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
                autofocus: photoPath == null,
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
                  date: DateTime.now(),
                  durationMinutes: 0,
                  method: 'bare_hand',
                  note: note.isEmpty ? null : note,
                  photoPaths: (photoPath != null && photoPath.isNotEmpty) ? [photoPath] : [],
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(antiqueRepositoryProvider);
                ref.invalidate(antiqueListProvider);
                ref.invalidate(categoryCountProvider);
                ref.invalidate(totalValuationProvider);
                if (mounted) setState(() {});
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
      ),
    );
  }

  // ===== 操作 =====

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
