/// 分类管理页面 — 管理文玩类别和待办分类。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/collection_category.dart';
import '../providers/category_management_providers.dart';
import '../../../todo/presentation/providers/todo_categories_provider.dart';
import '../../../../features/collection/presentation/providers/antique_providers.dart' show antiqueListProvider;

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends ConsumerState<CategoryManagementPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('分类管理'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.diamond), text: '文玩类别'),
              Tab(icon: Icon(Icons.task_alt), text: '待办分类'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCollectionCategories(context),
            _buildTodoCategories(context),
          ],
        ),
      ),
    );
  }

  // ===== 文玩类别管理 =====

  Widget _buildCollectionCategories(BuildContext context) {
    final cats = ref.watch(collectionCategoriesProvider);
    return Column(
      children: [
        _buildAddCategoryBar(context),
        const Divider(),
        Expanded(
          child: cats.isEmpty
              ? const Center(child: Text('暂无分类，请添加'))
              : ReorderableListView.builder(
                  itemCount: cats.length,
                  onReorder: (oldIndex, newIndex) {
                    ref.read(collectionCategoriesProvider.notifier).reorder(oldIndex, newIndex);
                  },
                  buildDefaultDragHandles: false,
                  itemBuilder: (_, i) => Card(
                    key: ValueKey('cat_${cats[i].name}'),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _buildCategoryCard(context, cats[i], i),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAddCategoryBar(BuildContext context) {
    final nameCtrl = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                hintText: '新文玩类别',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                ref.read(collectionCategoriesProvider.notifier).add(
                  CollectionCategory(name: nameCtrl.text.trim()),
                );
                nameCtrl.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, CollectionCategory cat, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            Icon(cat.name == '核桃' ? Icons.circle : Icons.grain, color: Colors.brown),
          ],
        ),
        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${cat.subtypes.length} 个子类型 · ${cat.metadataFields.length} 个字段'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editCategory(context, cat),
            ),
            if (index > 0)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: () => _deleteCategory(context, cat),
              ),
          ],
        ),
        children: [
          _buildSubtypesSection(context, cat),
          _buildMetadataFieldsSection(context, cat),
        ],
      ),
    );
  }

  Widget _buildSubtypesSection(BuildContext context, CollectionCategory cat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('子类型: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _showInputDialog(
                  context,
                  '为「${cat.name}」添加子类型',
                  '子类型名称',
                  (value) {
                    ref.read(collectionCategoriesProvider.notifier).update(
                      cat.name,
                      cat.copyWith(subtypes: [...cat.subtypes, value]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (cat.subtypes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('暂无子类型', style: TextStyle(fontSize: 11, color: Colors.grey)),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cat.subtypes.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final updated = [...cat.subtypes];
              final item = updated.removeAt(oldIndex);
              updated.insert(newIndex, item);
              ref.read(collectionCategoriesProvider.notifier).update(
                cat.name,
                cat.copyWith(subtypes: updated),
              );
            },
            buildDefaultDragHandles: false,
            itemBuilder: (_, i) {
              final st = cat.subtypes[i];
              return ReorderableDelayedDragStartListener(
                key: ValueKey('${cat.name}_st_$i'),
                index: i,
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Chip(
                      label: Text(st, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        final antiqueItems = ref.watch(antiqueListProvider).valueOrNull ?? [];
                        final count = antiqueItems.where((i) => i.category == cat.name && i.subtype == st).length;
                        if (count > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('「$st」有 $count 件藏品正在使用，不能删除')),
                          );
                          return;
                        }
                        ref.read(collectionCategoriesProvider.notifier).update(
                          cat.name,
                          cat.copyWith(subtypes: cat.subtypes.where((s) => s != st).toList()),
                        );
                      },
                    ),
                  ],
                ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMetadataFieldsSection(BuildContext context, CollectionCategory cat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Text('专属字段: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _showInputDialog(
                  context,
                  '为「${cat.name}」添加字段',
                  '字段名（如：重量(g)）',
                  (value) {
                    ref.read(collectionCategoriesProvider.notifier).update(
                      cat.name,
                      cat.copyWith(metadataFields: [...cat.metadataFields, value]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (cat.metadataFields.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('无专属字段', style: TextStyle(fontSize: 11, color: Colors.grey)),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cat.metadataFields.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final updated = [...cat.metadataFields];
              final item = updated.removeAt(oldIndex);
              updated.insert(newIndex, item);
              ref.read(collectionCategoriesProvider.notifier).update(
                cat.name,
                cat.copyWith(metadataFields: updated),
              );
            },
            buildDefaultDragHandles: false,
            itemBuilder: (_, i) {
              final f = cat.metadataFields[i];
              return ReorderableDelayedDragStartListener(
                key: ValueKey('${cat.name}_mf_$i'),
                index: i,
                child: Padding(
                padding: EdgeInsets.fromLTRB(16, 1, 16, i == cat.metadataFields.length - 1 ? 12 : 1),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Chip(
                      label: Text(f, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        ref.read(collectionCategoriesProvider.notifier).update(
                          cat.name,
                          cat.copyWith(metadataFields: cat.metadataFields.where((m) => m != f).toList()),
                        );
                      },
                    ),
                  ],
                ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _editCategory(BuildContext context, CollectionCategory cat) {
    _showInputDialog(
      context,
      '重命名分类',
      '分类名称',
      (value) {
        ref.read(collectionCategoriesProvider.notifier).update(
          cat.name,
          cat.copyWith(name: value),
        );
      },
      initialValue: cat.name,
    );
  }

  void _deleteCategory(BuildContext context, CollectionCategory cat) {
    // 检查有多少藏品使用了此分类
    final antiqueItems = ref.watch(antiqueListProvider).valueOrNull ?? [];
    final count = antiqueItems.where((i) => i.category == cat.name).length;

    if (count > 0) {
      // 有依赖项 → 禁止删除
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法删除'),
          content: Text('「${cat.name}」分类下有 $count 件藏品正在使用，请先移除或修改藏品的分类后再删除。'),
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
        content: Text('确定删除「${cat.name}」分类吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(collectionCategoriesProvider.notifier).remove(cat.name);
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
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
    final cats = ref.watch(todoCategoriesProvider).valueOrNull ?? [];
    final ctrl = TextEditingController();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    hintText: '新待办分类',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: () {
                  if (ctrl.text.trim().isNotEmpty) {
                    ref.read(todoCategoriesProvider.notifier).add(ctrl.text.trim());
                    ctrl.clear();
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            children: cats.map((cat) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(cat),
              trailing: (cat == '生活' || cat == '工作')
                  ? const Chip(label: Text('默认', style: TextStyle(fontSize: 11)))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showInputDialog(
                            context, '重命名分类', '分类名称',
                            (value) => ref.read(todoCategoriesProvider.notifier).rename(cat, value),
                            initialValue: cat,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => ref.read(todoCategoriesProvider.notifier).remove(cat),
                        ),
                      ],
                    ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
