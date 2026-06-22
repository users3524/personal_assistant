/// 藏品表单页 — 新建/编辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../../../core/models/collection_category.dart';
import '../../domain/entities/antique_entity.dart';
import '../providers/antique_providers.dart';
import '../widgets/resolved_image.dart';
import '../../../settings/presentation/providers/category_management_providers.dart'
    show collectionCategoriesProvider;

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
  late TextEditingController _subtypeCtrl;

  // 分类专属字段控制器 (按分类字段名索引)
  final _metaCtrls = <String, TextEditingController>{};

  // 从 Provider 加载的分类数据
  List<CollectionCategory> _categories = [];
  String _category = '';
  String? _subtype;
  DateTime _acquiredDate = DateTime.now();
  AntiqueCondition _condition = AntiqueCondition.good;
  List<String> _imagePaths = [];
  bool _isLoading = false;
  bool _isSavingImage = false;

  bool get _isEditing => widget.editId != null;

  /// 当前分类的分类模型
  CollectionCategory? get _currentCategoryModel {
    try {
      return _categories.firstWhere((c) => c.name == _category);
    } catch (_) {
      return null;
    }
  }

  /// 当前分类的细分列表
  List<String> get _currentSubtypes => _currentCategoryModel?.subtypes ?? [];

  /// 当前分类的专属字段
  List<String> get _currentFields =>
      _currentCategoryModel?.metadataFields ?? [];

  /// 获取实际展示的字段列表（分类模型未加载时用硬编码兜底）
  List<String> _getDisplayFields() {
    if (_currentFields.isNotEmpty) return _currentFields;
    if (_category == '核桃') return ['边宽(mm)', '肚厚(mm)', '桩高(mm)', '重量(g)'];
    return [];
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _sellerCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _subtypeCtrl = TextEditingController();
    // 延迟加载分类数据
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    final cats = ref.read(collectionCategoriesProvider);
    if (!mounted) return;
    setState(() {
      _categories = cats;
      if (_category.isEmpty && cats.isNotEmpty) {
        _category = cats.first.name;
      }
      _initMetaCtrls();
      if (_isEditing) _loadExisting();
    });
  }

  void _initMetaCtrls() {
    _metaCtrls.clear();
    for (final f in _currentFields) {
      _metaCtrls[f] = TextEditingController();
    }
    // 如果当前是核桃但字段为空，从默认分类数据中补充
    if (_currentFields.isEmpty && _category == '核桃') {
      const walnutDefaults = ['边宽(mm)', '肚厚(mm)', '桩高(mm)', '重量(g)'];
      for (final f in walnutDefaults) {
        _metaCtrls[f] = TextEditingController();
      }
    }
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
        _subtypeCtrl.text = item.subtype ?? '';
        // 回填分类专属字段 — 直接从 item.categoryMetadata 构建控制器，不依赖分类模型
        _metaCtrls.clear();
        if (item.categoryMetadata != null &&
            item.categoryMetadata!.isNotEmpty) {
          for (final e in item.categoryMetadata!.entries) {
            if (_category == '核桃' && e.value.contains(',')) {
              final parts = e.value.split(',');
              _metaCtrls['左${e.key}'] = TextEditingController(
                text: parts[0].trim(),
              );
              _metaCtrls['右${e.key}'] = TextEditingController(
                text: parts.length > 1 ? parts[1].trim() : '',
              );
            } else {
              _metaCtrls[e.key] = TextEditingController(text: e.value);
            }
          }
        } else {
          _initMetaCtrls();
        }
        _acquiredDate = item.acquiredDate;
        _condition = item.condition;
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
    _subtypeCtrl.dispose();
    for (final c in _metaCtrls.values) {
      c.dispose();
    }
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存图片失败: $e')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存图片失败: $e')));
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
    // 存相对路径，App 更新后沙盒路径变化也不影响
    return 'antique_images/$fileName';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();

      // 收集分类专属字段
      final fields = _getDisplayFields();
      final metadata = <String, String>{};
      if (_category == '核桃') {
        for (final f in fields) {
          final leftCtrl = _metaCtrls['左$f'];
          final rightCtrl = _metaCtrls['右$f'];
          final left = leftCtrl?.text.trim() ?? '';
          final right = rightCtrl?.text.trim() ?? '';
          if (left.isNotEmpty || right.isNotEmpty) {
            metadata[f] = '$left,$right';
          }
        }
      } else {
        for (final f in fields) {
          final ctrl = _metaCtrls[f];
          if (ctrl != null && ctrl.text.trim().isNotEmpty) {
            metadata[f] = ctrl.text.trim();
          }
        }
      }

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
        imagePaths: _imagePaths,
        categoryMetadata: metadata.isNotEmpty ? metadata : null,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final repo = await ref.read(antiqueRepositoryProvider.future);

      if (_isEditing) {
        await repo.update(item);
      } else {
        final created = await repo.create(item);
        // 新建时自动创建首条打卡记录（入手当天，含藏品照片）
        await repo.addPattingLog(
          PattingLogEntity(
            itemId: created.id!,
            date: _acquiredDate,
            durationMinutes: 0,
            method: 'bare_hand',
            note: null,
            photoPaths: _imagePaths,
          ),
        );
      }

      // 如果分类不在预设列表中，自动添加
      final catNotifier = ref.read(collectionCategoriesProvider.notifier);
      if (!catNotifier.state.any((c) => c.name == _category)) {
        catNotifier.add(
          CollectionCategory(
            name: _category,
            sortOrder: catNotifier.state.length,
          ),
        );
      }

      // 刷新列表
      ref.invalidate(antiqueListProvider);
      ref.invalidate(categoryCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_isEditing ? '已更新' : '已添加')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 14),
                    AppPageHeader(
                      title: _isEditing ? '编辑藏品' : '新增藏品',
                      subtitle: '记录尺寸、来源和每一次盘玩的开始',
                    ),
                    const SizedBox(height: 18),
                    _buildImageSection(),
                    const SizedBox(height: 24),

                    const AppSectionTitle(
                      title: '基础参数',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    _buildBasicSection(),
                    const SizedBox(height: 24),

                    const AppSectionTitle(
                      title: '特有参数',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    _buildSpecialSection(),
                    const SizedBox(height: 32),

                    FilledButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isEditing ? '保存修改' : '创建藏品'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppColors.primary,
          ),
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left),
          label: const Text('返回'),
        ),
        const Spacer(),
        TextButton(
          onPressed: _isLoading ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      borderColor: AppColors.muted.withValues(alpha: 0.35),
      onTap: _imagePaths.isEmpty && !_isSavingImage
          ? _showImagePickerOptions
          : null,
      child: _imagePaths.isEmpty
          ? _buildEmptyImageUpload()
          : SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagePaths.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == _imagePaths.length) {
                    return _buildAddImageButton();
                  }
                  return _buildImageThumb(index);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyImageUpload() {
    return SizedBox(
      height: 112,
      child: Center(
        child: _isSavingImage
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 34,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '上传封面图',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '支持拍照或从相册选择',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBasicSection() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: _fieldDecoration(
              label: '藏品名称',
              hint: '例如：南疆石狮子头',
              icon: Icons.diamond_outlined,
            ),
            validator: (v) => v == null || v.trim().isEmpty ? '名称不能为空' : null,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _buildCategorySelector(),
          const SizedBox(height: 14),
          TextFormField(
            controller: _priceCtrl,
            decoration: _fieldDecoration(
              label: '入手价格',
              hint: '可选',
              icon: Icons.payments_outlined,
              prefixText: '¥ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _sellerCtrl,
            decoration: _fieldDecoration(
              label: '入手渠道',
              hint: '例如：潘家园、朋友转让',
              icon: Icons.storefront_outlined,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _DateRow(
            icon: Icons.calendar_today_outlined,
            label: '入手日期',
            value: _formatDate(_acquiredDate),
            onTap: _pickDate,
          ),
          const SizedBox(height: 14),
          _buildConditionSelector(),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('分类'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ..._categories.map((cat) {
                final selected = _category == cat.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildChoicePill(
                    label: cat.name,
                    icon: _categoryIcon(cat.name),
                    color: _categoryColor(cat.name),
                    isSelected: selected,
                    onTap: () {
                      setState(() {
                        _category = cat.name;
                        _subtype = null;
                        _subtypeCtrl.text = '';
                        _initMetaCtrls();
                      });
                    },
                  ),
                );
              }),
              if (_category.isNotEmpty &&
                  _categories.every((c) => c.name != _category))
                _buildChoicePill(
                  label: _category,
                  icon: Icons.category_outlined,
                  color: AppColors.primary,
                  isSelected: true,
                  onTap: () {},
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          decoration: _fieldDecoration(
            hint: '自定义分类',
            icon: Icons.edit_outlined,
          ),
          onChanged: (v) {
            if (v.trim().isNotEmpty) {
              setState(() {
                _category = v.trim();
                _subtype = null;
                _subtypeCtrl.text = '';
                _initMetaCtrls();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildSpecialSection() {
    final fields = _getDisplayFields();

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubtypeSelector(),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (fields.isEmpty)
            const Text(
              '当前分类暂无专属字段，可先用备注记录细节。',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            )
          else
            _buildMetadataFields(fields),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notesCtrl,
            decoration: _fieldDecoration(
              label: '通用备注',
              hint: '记录来源、瑕疵、盘玩手感等细节',
              icon: Icons.notes_outlined,
            ),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
        ],
      ),
    );
  }

  Widget _buildSubtypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('细分品类'),
        if (_currentSubtypes.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _currentSubtypes.map((sub) {
                final selected = _subtype == sub;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildChoicePill(
                    label: sub,
                    icon: Icons.label_outline,
                    color: AppColors.primary,
                    isSelected: selected,
                    onTap: () {
                      setState(() {
                        _subtype = selected ? null : sub;
                        _subtypeCtrl.text = selected ? '' : sub;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          decoration: _fieldDecoration(
            hint: '自定义细分品类',
            icon: Icons.sell_outlined,
          ),
          controller: _subtypeCtrl,
          onChanged: (v) {
            setState(() => _subtype = v.trim().isEmpty ? null : v.trim());
          },
        ),
      ],
    );
  }

  Widget _buildMetadataFields(List<String> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('详细参数'),
        const SizedBox(height: 10),
        if (_category == '核桃')
          ...fields.map(_buildWalnutMetaField)
        else
          ...fields.map(_buildSingleMetaField),
      ],
    );
  }

  Widget _buildWalnutMetaField(String field) {
    final leftCtrl = _metaCtrls['左$field'] ??= TextEditingController();
    final rightCtrl = _metaCtrls['右$field'] ??= TextEditingController();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: leftCtrl,
                  decoration: _fieldDecoration(hint: '左', prefixText: '左 '),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: rightCtrl,
                  decoration: _fieldDecoration(hint: '右', prefixText: '右 '),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleMetaField(String field) {
    final isNumeric =
        field.contains('mm') || field.contains('重量') || field.contains('尺寸');
    final controller = _metaCtrls[field] ??= TextEditingController();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: _fieldDecoration(label: field, hint: field),
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: isNumeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
            : null,
      ),
    );
  }

  Widget _buildConditionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('品相'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AntiqueCondition.values.map((condition) {
            return _buildChoicePill(
              label: _conditionLabel(condition),
              icon: _conditionIcon(condition),
              color: _conditionColor(condition),
              isSelected: _condition == condition,
              onTap: () => setState(() => _condition = condition),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChoicePill({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? color : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    IconData? icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      prefixText: prefixText,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  String _conditionLabel(AntiqueCondition condition) {
    switch (condition) {
      case AntiqueCondition.perfect:
        return '全品';
      case AntiqueCondition.good:
        return '良好';
      case AntiqueCondition.fair:
        return '一般';
      case AntiqueCondition.poor:
        return '有损';
    }
  }

  IconData _conditionIcon(AntiqueCondition condition) {
    switch (condition) {
      case AntiqueCondition.perfect:
        return Icons.verified_outlined;
      case AntiqueCondition.good:
        return Icons.thumb_up_alt_outlined;
      case AntiqueCondition.fair:
        return Icons.remove_circle_outline;
      case AntiqueCondition.poor:
        return Icons.report_problem_outlined;
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

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _isSavingImage ? null : () => _showImagePickerOptions(),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
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
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 6),
                  Text(
                    '添加',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: ResolvedImage(
              path: _imagePaths[index],
              fit: BoxFit.cover,
              placeholder: Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(Icons.photo_outlined, color: AppColors.muted),
                ),
              ),
              error: Container(
                color: AppColors.surface,
                child: const Center(
                  child: Icon(Icons.broken_image, color: AppColors.muted),
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
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.72),
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
      backgroundColor: AppColors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.muted,
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
