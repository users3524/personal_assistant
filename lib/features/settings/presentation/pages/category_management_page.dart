/// 分类管理页面 — 管理文玩类别和待办分类。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../../../core/models/collection_category.dart';
import '../../../../features/collection/presentation/providers/antique_providers.dart'
    show antiqueListProvider;
import '../../../todo/presentation/providers/todo_categories_provider.dart';
import '../providers/category_management_providers.dart';

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends ConsumerState<CategoryManagementPage> {
  final _collectionNameCtrl = TextEditingController();
  final _todoNameCtrl = TextEditingController();

  @override
  void dispose() {
    _collectionNameCtrl.dispose();
    _todoNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _buildTabs(),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildCollectionCategories(context),
                    _buildTodoCategories(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left),
            label: const Text('返回'),
          ),
          const Expanded(
            child: Text(
              '分类管理',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(4),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        tabs: const [
          Tab(icon: Icon(Icons.diamond_outlined), text: '文玩类别'),
          Tab(icon: Icon(Icons.task_alt), text: '待办分类'),
        ],
      ),
    );
  }

  // ===== 文玩类别管理 =====

  Widget _buildCollectionCategories(BuildContext context) {
    final categories = ref.watch(collectionCategoriesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildAddBar(
            controller: _collectionNameCtrl,
            hintText: '新文玩类别',
            onAdd: () {
              final name = _collectionNameCtrl.text.trim();
              if (name.isEmpty) return;
              ref
                  .read(collectionCategoriesProvider.notifier)
                  .add(CollectionCategory(name: name));
              _collectionNameCtrl.clear();
            },
          ),
        ),
        Expanded(
          child: categories.isEmpty
              ? const Center(
                  child: Text(
                    '暂无分类，请添加',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: categories.length,
                  onReorder: (oldIndex, newIndex) {
                    ref
                        .read(collectionCategoriesProvider.notifier)
                        .reorder(oldIndex, newIndex);
                  },
                  buildDefaultDragHandles: false,
                  itemBuilder: (_, index) {
                    final category = categories[index];
                    return _buildCategoryCard(context, category, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAddBar({
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onAdd,
  }) {
    return AppSurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
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
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.add),
            tooltip: '添加',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    CollectionCategory category,
    int index,
  ) {
    return AppSurfaceCard(
      key: ValueKey('cat_${category.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Icon(
                Icons.drag_handle,
                size: 20,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(width: 6),
            Icon(_categoryIcon(category.name), color: AppColors.primary),
          ],
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        subtitle: Text(
          '${category.subtypes.length} 个子类型 · ${category.metadataFields.length} 个字段',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: '重命名',
              onPressed: () => _editCategory(context, category),
            ),
            if (index > 0)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.red,
                ),
                tooltip: '删除',
                onPressed: () => _deleteCategory(context, category),
              ),
          ],
        ),
        children: [
          _buildSubtypesSection(context, category),
          _buildMetadataFieldsSection(context, category),
        ],
      ),
    );
  }

  Widget _buildSubtypesSection(BuildContext context, CollectionCategory cat) {
    return _buildChipSection(
      title: '子类型',
      emptyText: '暂无子类型',
      onAdd: () => _showInputDialog(context, '为「${cat.name}」添加子类型', '子类型名称', (
        value,
      ) {
        ref
            .read(collectionCategoriesProvider.notifier)
            .update(cat.name, cat.copyWith(subtypes: [...cat.subtypes, value]));
      }),
      child: cat.subtypes.isEmpty
          ? null
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cat.subtypes.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final updated = [...cat.subtypes];
                final item = updated.removeAt(oldIndex);
                updated.insert(newIndex, item);
                ref
                    .read(collectionCategoriesProvider.notifier)
                    .update(cat.name, cat.copyWith(subtypes: updated));
              },
              buildDefaultDragHandles: false,
              itemBuilder: (_, index) {
                final subtype = cat.subtypes[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey('${cat.name}_subtype_$index'),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(subtype),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _deleteSubtype(context, cat, subtype),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMetadataFieldsSection(
    BuildContext context,
    CollectionCategory cat,
  ) {
    return _buildChipSection(
      title: '专属字段',
      emptyText: '无专属字段',
      onAdd: () => _showInputDialog(
        context,
        '为「${cat.name}」添加字段',
        '字段名（如：重量(g)）',
        (value) {
          ref
              .read(collectionCategoriesProvider.notifier)
              .update(
                cat.name,
                cat.copyWith(metadataFields: [...cat.metadataFields, value]),
              );
        },
      ),
      child: cat.metadataFields.isEmpty
          ? null
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cat.metadataFields.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final updated = [...cat.metadataFields];
                final item = updated.removeAt(oldIndex);
                updated.insert(newIndex, item);
                ref
                    .read(collectionCategoriesProvider.notifier)
                    .update(cat.name, cat.copyWith(metadataFields: updated));
              },
              buildDefaultDragHandles: false,
              itemBuilder: (_, index) {
                final field = cat.metadataFields[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey('${cat.name}_field_$index'),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(field),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          ref
                              .read(collectionCategoriesProvider.notifier)
                              .update(
                                cat.name,
                                cat.copyWith(
                                  metadataFields: cat.metadataFields
                                      .where((m) => m != field)
                                      .toList(),
                                ),
                              );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildChipSection({
    required String title,
    required String emptyText,
    required VoidCallback onAdd,
    required Widget? child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: '添加',
                onPressed: onAdd,
              ),
            ],
          ),
        ),
        child ??
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                emptyText,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
      ],
    );
  }

  void _deleteSubtype(
    BuildContext context,
    CollectionCategory cat,
    String subtype,
  ) {
    final antiqueItems = ref.read(antiqueListProvider).valueOrNull ?? [];
    final count = antiqueItems
        .where((item) => item.category == cat.name && item.subtype == subtype)
        .length;
    if (count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$subtype」有 $count 件藏品正在使用，不能删除')),
      );
      return;
    }

    ref
        .read(collectionCategoriesProvider.notifier)
        .update(
          cat.name,
          cat.copyWith(
            subtypes: cat.subtypes.where((s) => s != subtype).toList(),
          ),
        );
  }

  IconData _categoryIcon(String name) {
    if (name.contains('核桃')) return Icons.circle_outlined;
    if (name.contains('串')) return Icons.grain_outlined;
    if (name.contains('把件')) return Icons.category_outlined;
    return Icons.diamond_outlined;
  }

  void _editCategory(BuildContext context, CollectionCategory category) {
    _showInputDialog(context, '重命名分类', '分类名称', (value) {
      ref
          .read(collectionCategoriesProvider.notifier)
          .update(category.name, category.copyWith(name: value));
    }, initialValue: category.name);
  }

  void _deleteCategory(BuildContext context, CollectionCategory category) {
    final antiqueItems = ref.read(antiqueListProvider).valueOrNull ?? [];
    final count = antiqueItems
        .where((item) => item.category == category.name)
        .length;

    if (count > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法删除'),
          content: Text(
            '「${category.name}」分类下有 $count 件藏品正在使用，请先移除或修改藏品的分类后再删除。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除「${category.name}」分类吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () {
              ref
                  .read(collectionCategoriesProvider.notifier)
                  .remove(category.name);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showInputDialog(
    BuildContext context,
    String title,
    String hint,
    void Function(String) onSave, {
    String initialValue = '',
  }) {
    final ctrl = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onSave(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ===== 待办分类管理 =====

  Widget _buildTodoCategories(BuildContext context) {
    final categories = ref.watch(todoCategoriesProvider).valueOrNull ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildAddBar(
            controller: _todoNameCtrl,
            hintText: '新待办分类',
            onAdd: () {
              final name = _todoNameCtrl.text.trim();
              if (name.isEmpty) return;
              ref.read(todoCategoriesProvider.notifier).add(name);
              _todoNameCtrl.clear();
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: categories.map((category) {
              final isDefault = category == '生活' || category == '工作';
              return AppSurfaceCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    category,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: isDefault
                      ? const AppPill(label: '默认', color: AppColors.green)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: '重命名',
                              onPressed: () => _showInputDialog(
                                context,
                                '重命名分类',
                                '分类名称',
                                (value) => ref
                                    .read(todoCategoriesProvider.notifier)
                                    .rename(category, value),
                                initialValue: category,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.red,
                              ),
                              tooltip: '删除',
                              onPressed: () => ref
                                  .read(todoCategoriesProvider.notifier)
                                  .remove(category),
                            ),
                          ],
                        ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
