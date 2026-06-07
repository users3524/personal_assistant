/// 藏品表单页 — 新建/编辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';

/// 预置分类
const kPresetCategories = [
  '松石', '南红', '菩提', '翡翠', '和田玉',
  '紫砂', '书画', '核桃', '葫芦', '杂项',
];

class AntiqueFormPage extends ConsumerStatefulWidget {
  final int? editId;

  const AntiqueFormPage({super.key, this.editId});

  @override
  ConsumerState<AntiqueFormPage> createState() => _AntiqueFormPageState();
}

class _AntiqueFormPageState extends ConsumerState<AntiqueFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _sellerCtrl;
  late TextEditingController _notesCtrl;

  String _category = kPresetCategories[0];
  String? _subtype;
  DateTime _acquiredDate = DateTime.now();
  AntiqueCondition _condition = AntiqueCondition.good;
  double? _currentValuation;
  List<String> _imagePaths = [];
  bool _isLoading = false;
  bool _isSavingImage = false;

  bool get _isEditing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _sellerCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    final repo = await ref.read(antiqueRepositoryProvider.future);
    final item = await repo.getById(widget.editId!);
    if (item != null && mounted) {
      setState(() {
        _nameCtrl.text = item.name;
        _priceCtrl.text = item.acquiredPrice?.toStringAsFixed(2) ?? '';
        _sellerCtrl.text = item.sourceSeller ?? '';
        _notesCtrl.text = item.notes ?? '';
        _category = item.category;
        _subtype = item.subtype;
        _acquiredDate = item.acquiredDate;
        _condition = item.condition;
        _currentValuation = item.currentValuation;
        _imagePaths = List.from(item.imagePaths);
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _sellerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (file != null && mounted) {
      setState(() => _isSavingImage = true);
      try {
        final savedPath = await _saveImageToAppDir(file);
        setState(() => _imagePaths.add(savedPath));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存图片失败: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSavingImage = false);
      }
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (file != null && mounted) {
      setState(() => _isSavingImage = true);
      try {
        final savedPath = await _saveImageToAppDir(file);
        setState(() => _imagePaths.add(savedPath));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存图片失败: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSavingImage = false);
      }
    }
  }

  /// 将 XFile 保存到应用私有目录（解决 content:// URI 无法被 File() 读取的问题）
  Future<String> _saveImageToAppDir(XFile photo) async {
    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/antique_images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    final fileName = 'antique_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File('${imgDir.path}/$fileName');
    final bytes = await photo.readAsBytes();
    await dest.writeAsBytes(bytes);
    return dest.path;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final item = AntiqueEntity(
        id: widget.editId,
        name: _nameCtrl.text.trim(),
        category: _category,
        subtype: _subtype,
        acquiredDate: _acquiredDate,
        acquiredPrice: double.tryParse(_priceCtrl.text),
        sourceSeller: _sellerCtrl.text.trim().isEmpty
            ? null
            : _sellerCtrl.text.trim(),
        condition: _condition,
        currentValuation: _currentValuation,
        imagePaths: _imagePaths,
        notes: _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final repo = await ref.read(antiqueRepositoryProvider.future);

      if (_isEditing) {
        await repo.update(item);
      } else {
        final created = await repo.create(item);
        // 新建时自动创建首条打卡记录（入手当天，含藏品照片）
        await repo.addPattingLog(PattingLogEntity(
          itemId: created.id!,
          date: _acquiredDate,
          durationMinutes: 0,
          method: 'bare_hand',
          note: '入手',
          photoPaths: _imagePaths,
        ));
      }

      // 刷新列表
      ref.invalidate(antiqueListProvider);
      ref.invalidate(categoryCountProvider);
      ref.invalidate(totalValuationProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '已更新' : '已添加')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑藏品' : '新增藏品'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        hintText: '输入藏品名称',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '名称不能为空' : null,
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),

                    // 分类
                    Text('分类', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ...kPresetCategories.map((cat) {
                          final selected = _category == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: selected,
                            onSelected: (sel) =>
                                setState(() => _category = cat),
                          );
                        }).toList(),
                        if (!kPresetCategories.contains(_category))
                          ChoiceChip(
                            label: Text(_category),
                            selected: true,
                            onSelected: null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: '自定义分类',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (v) {
                              if (v.trim().isNotEmpty) {
                                setState(() => _category = v.trim());
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 入手日期
                    Text('入手日期',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${_acquiredDate.year}-${_acquiredDate.month.toString().padLeft(2, '0')}-${_acquiredDate.day.toString().padLeft(2, '0')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 入手价格
                    TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                        labelText: '入手价格（元）',
                        hintText: '可选',
                        prefixText: '¥ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // 来源
                    TextFormField(
                      controller: _sellerCtrl,
                      decoration: const InputDecoration(
                        labelText: '来源 / 卖家',
                        hintText: '可选',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 品相
                    Text('品相', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<AntiqueCondition>(
                      segments: const [
                        ButtonSegment(
                            value: AntiqueCondition.perfect,
                            label: Text('全品')),
                        ButtonSegment(
                            value: AntiqueCondition.good,
                            label: Text('良好')),
                        ButtonSegment(
                            value: AntiqueCondition.fair,
                            label: Text('一般')),
                        ButtonSegment(
                            value: AntiqueCondition.poor,
                            label: Text('有损')),
                      ],
                      selected: {_condition},
                      onSelectionChanged: (sel) =>
                          setState(() => _condition = sel.first),
                    ),
                    const SizedBox(height: 16),

                    // 图片
                    Text('照片', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagePaths.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == _imagePaths.length) {
                            return _buildAddImageButton();
                          }
                          return _buildImageThumb(index);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 备注
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        hintText: '可选',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _isSavingImage ? null : () => _showImagePickerOptions(),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _isSavingImage
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                  SizedBox(height: 4),
                  Text('添加', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
      ),
    );
  }

  Widget _buildImageThumb(int index) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_imagePaths[index]),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _imagePaths.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _acquiredDate,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _acquiredDate = date);
  }
}
