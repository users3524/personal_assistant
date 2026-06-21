/// 待办表单页 — 新建/编辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  '生活': Colors.green,
  '工作': Colors.blue,
  '学习': Colors.purple,
  '健康': Colors.red,
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
      appBar: AppBar(
        title: Text(_isEditing ? '编辑待办' : '新建待办'),
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
                    // 标题
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '输入待办标题',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '标题不能为空' : null,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // 描述
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: '描述（可选）',
                        hintText: '输入详细描述',
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 24),

                    // 分类
                    Text('分类', style: Theme.of(context).textTheme.titleMedium),
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
                                          _categoryColors[cat] ?? Colors.teal,
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
                        child: Chip(
                          label: Text(_category),
                          avatar: const Icon(Icons.category, size: 16),
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

                    Text('清单', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _buildTodoListSelector(),
                    const SizedBox(height: 24),

                    // 优先级
                    Text('优先级', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final starLevel = index + 1;
                        return IconButton(
                          icon: Icon(
                            starLevel <= _priority
                                ? Icons.star
                                : Icons.star_border,
                            color: starLevel <= _priority
                                ? _getPriorityColor(starLevel)
                                : Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _priority = starLevel),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // 开始时间（必填）
                    Text(
                      '开始时间 *',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickStartedAt,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_outline, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${_startedAt.year}-${_startedAt.month.toString().padLeft(2, '0')}-${_startedAt.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 截止日期
                    Text(
                      '截止日期',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _dueDate != null
                                  ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                  : '点击选择日期',
                              style: TextStyle(
                                color: _dueDate != null ? null : Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            if (_dueDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => _dueDate = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

        return Row(
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
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
        return Colors.grey;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      case 5:
        return Colors.deepOrange;
      default:
        return Colors.grey;
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
