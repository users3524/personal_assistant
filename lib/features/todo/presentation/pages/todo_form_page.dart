/// 待办表单页 — 新建/编辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../domain/entities/todo_entity.dart';
import '../providers/todo_providers.dart';
import '../providers/todo_categories_provider.dart';

const _categoryIcons = {
  '生活': Icons.home,
  '工作': Icons.work,
  '学习': Icons.school,
  '健康': Icons.favorite,
};

const _categoryColors = {
  '生活': AppColors.green,
  '工作': AppColors.blue,
  '学习': AppColors.primary,
  '健康': AppColors.red,
};

class TodoFormPage extends ConsumerStatefulWidget {
  final int? editId;
  final int? initialListId;
  final String? initialCategory;

  const TodoFormPage({
    super.key,
    this.editId,
    this.initialListId,
    this.initialCategory,
  });

  @override
  ConsumerState<TodoFormPage> createState() => _TodoFormPageState();
}

class _TodoFormPageState extends ConsumerState<TodoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _categoryController;

  TodoEntity? _editingTodo;
  String _category = '生活';
  int? _listId;
  int _priority = 3;
  DateTime? _dueDate;
  late DateTime _startedAt;
  DateTime? _originalCreatedAt;
  bool _isLoading = false;

  bool get _isEditing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _categoryController = TextEditingController();
    _category = widget.initialCategory ?? _category;
    _listId = widget.initialListId;
    _startedAt = DateTime.now();
    if (_isEditing) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    final repo = ref.read(todoRepositoryProvider).requireValue;
    final todo = await repo.getById(widget.editId!);
    if (todo != null && mounted) {
      setState(() {
        _editingTodo = todo;
        _titleController.text = todo.title;
        _descController.text = todo.description ?? '';
        _category = todo.category;
        _categoryController.text = todo.category;
        _listId = todo.listId;
        _priority = todo.priority;
        _dueDate = todo.dueDate;
        _startedAt = todo.startedAt ?? todo.createdAt;
        _originalCreatedAt = todo.createdAt;
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final existing = _editingTodo;
      final todoLists = ref.read(todoListsProvider).valueOrNull;
      final selectedList = _findTodoList(todoLists ?? const [], _listId);
      final resolvedListId = todoLists == null || selectedList != null
          ? _listId
          : null;
      final resolvedCategory = selectedList?.category ?? _category;
      final todo = TodoEntity(
        id: widget.editId,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        category: resolvedCategory,
        priority: _priority,
        dueDate: _dueDate,
        status: existing?.status ?? TodoStatus.pending,
        tags: existing?.tags ?? const [],
        isStarred: existing?.isStarred ?? false,
        startedAt: _startedAt,
        completedAt: existing?.completedAt,
        cancelledAt: existing?.cancelledAt,
        deletedAt: existing?.deletedAt,
        actualMinutes: existing?.actualMinutes,
        delayCount: existing?.delayCount ?? 0,
        createdAt: _originalCreatedAt ?? now,
        updatedAt: now,
        listId: resolvedListId,
        parentId: existing?.parentId,
        subtasks: existing?.subtasks ?? const [],
        recurrenceRule: existing?.recurrenceRule,
      );

      final notifier = ref.read(todoListProvider.notifier);
      if (_isEditing) {
        await notifier.updateTodo(todo);
      } else {
        await notifier.addTodo(todo);
      }

      // 如果分类不在预设列表中，自动添加
      final catsNotifier = ref.read(todoCategoriesProvider.notifier);
      final currentCats = ref.read(todoCategoriesProvider).valueOrNull ?? [];
      if (!currentCats.contains(resolvedCategory)) {
        catsNotifier.add(resolvedCategory);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_isEditing ? '已更新' : '已创建')));
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
                      title: _isEditing ? '编辑待办' : '新建待办',
                      subtitle: '把任务拆到可执行、可追踪',
                    ),
                    const SizedBox(height: 18),
                    AppSurfaceCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: '标题',
                              hintText: '输入待办标题',
                              prefixIcon: Icon(Icons.task_alt_outlined),
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? '标题不能为空' : null,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descController,
                            decoration: const InputDecoration(
                              labelText: '描述（可选）',
                              hintText: '输入详细描述',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                            maxLines: 3,
                            textInputAction: TextInputAction.newline,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const AppSectionTitle(
                      title: '分类',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Consumer(
                        builder: (ctx, ref, _) {
                          final cats =
                              ref.watch(todoCategoriesProvider).valueOrNull ??
                              ['生活', '工作'];
                          return Row(
                            children: cats
                                .map(
                                  (cat) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildCategoryChoice(
                                      label: cat,
                                      icon:
                                          _categoryIcons[cat] ?? Icons.category,
                                      color:
                                          _categoryColors[cat] ??
                                          AppColors.primary,
                                      isSelected: _category == cat,
                                      onTap: () => setState(() {
                                        _category = cat;
                                        _listId = null;
                                        _categoryController.clear();
                                      }),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ),
                    if (!(ref.watch(todoCategoriesProvider).valueOrNull ??
                            ['生活', '工作'])
                        .contains(_category))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AppPill(
                          label: _category,
                          color: AppColors.primary,
                          icon: Icons.category,
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        hintText: '自定义分类（输入后点击保存即新增）',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (v) {
                        if (v.trim().isNotEmpty) {
                          setState(() {
                            _category = v.trim();
                            _listId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    const AppSectionTitle(
                      title: '清单',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    _buildTodoListSelector(),
                    const SizedBox(height: 24),

                    const AppSectionTitle(
                      title: '优先级',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    AppSurfaceCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: List.generate(5, (index) {
                          final starLevel = index + 1;
                          return Expanded(
                            child: IconButton(
                              icon: Icon(
                                starLevel <= _priority
                                    ? Icons.star
                                    : Icons.star_border,
                                color: starLevel <= _priority
                                    ? _getPriorityColor(starLevel)
                                    : AppColors.line,
                              ),
                              onPressed: () =>
                                  setState(() => _priority = starLevel),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const AppSectionTitle(
                      title: '时间',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    AppSurfaceCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _DateRow(
                            icon: Icons.play_circle_outline,
                            label: '开始时间',
                            value:
                                '${_startedAt.year}-${_startedAt.month.toString().padLeft(2, '0')}-${_startedAt.day.toString().padLeft(2, '0')}',
                            onTap: _pickStartedAt,
                          ),
                          const Divider(height: 1),
                          _DateRow(
                            icon: Icons.calendar_today,
                            label: '截止日期',
                            value: _dueDate != null
                                ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                : '点击选择日期',
                            muted: _dueDate == null,
                            onTap: _pickDate,
                            trailing: _dueDate == null
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () =>
                                        setState(() => _dueDate = null),
                                  ),
                          ),
                        ],
                      ),
                    ),
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
                      label: Text(_isEditing ? '保存修改' : '创建待办'),
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

  Widget _buildTodoListSelector() {
    final todoListsAsync = ref.watch(todoListsProvider);

    return todoListsAsync.when(
      data: (lists) {
        final visibleLists = [...lists]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final selectedListId = visibleLists.any((list) => list.id == _listId)
            ? _listId
            : null;

        return AppSurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                    'todo_list_${selectedListId ?? unlistedTodoListFilter}_${visibleLists.length}',
                  ),
                  initialValue: selectedListId ?? unlistedTodoListFilter,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: unlistedTodoListFilter,
                      child: Text('不放入清单'),
                    ),
                    ...visibleLists.map(
                      (list) => DropdownMenuItem<int>(
                        value: list.id,
                        child: Text(list.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    final newListId = value == unlistedTodoListFilter
                        ? null
                        : value;
                    final selected = _findTodoList(visibleLists, newListId);
                    setState(() {
                      _listId = newListId;
                      if (selected != null) {
                        _category = selected.category;
                        _categoryController.clear();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '新建清单',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => _showListDialog(category: _category),
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (err, _) => Text('清单加载失败: $err'),
    );
  }

  TodoListEntity? _findTodoList(List<TodoListEntity> lists, int? id) {
    if (id == null) return null;
    for (final list in lists) {
      if (list.id == id) return list;
    }
    return null;
  }

  Future<void> _showListDialog({TodoListEntity? list, String? category}) async {
    final nameController = TextEditingController(text: list?.name ?? '');
    final categories = [
      ...(ref.read(todoCategoriesProvider).valueOrNull ?? ['生活', '工作']),
    ];
    var selectedCategory = list?.category ?? category ?? _category;
    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }

    final saved = await showDialog<TodoListEntity>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(list == null ? '新建清单' : '编辑清单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: '清单名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: '所属分类',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: categories
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCategory = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final now = DateTime.now();
                final savedList = await ref
                    .read(todoListsProvider.notifier)
                    .saveList(
                      TodoListEntity(
                        id: list?.id,
                        name: name,
                        category: selectedCategory,
                        createdAt: list?.createdAt ?? now,
                      ),
                    );
                if (ctx.mounted) Navigator.pop(ctx, savedList);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    if (saved != null && mounted) {
      setState(() {
        _category = saved.category;
        _categoryController.clear();
        _listId = saved.id;
      });
    }
  }

  Widget _buildCategoryChoice({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? Border.all(color: color, width: 1.5)
              : Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppColors.muted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(int level) {
    switch (level) {
      case 1:
        return AppColors.muted;
      case 2:
        return AppColors.green;
      case 3:
        return AppColors.orange;
      case 4:
        return AppColors.red;
      case 5:
        return AppColors.red;
      default:
        return AppColors.muted;
    }
  }

  Future<void> _pickStartedAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _startedAt = date);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: muted ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
