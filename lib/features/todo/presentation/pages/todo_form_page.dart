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

  const TodoFormPage({super.key, this.editId});

  @override
  ConsumerState<TodoFormPage> createState() => _TodoFormPageState();
}

class _TodoFormPageState extends ConsumerState<TodoFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;

  String _category = '生活';
  int _priority = 3;
  DateTime? _dueDate;
  DateTime _createDate = DateTime.now();
  bool _isLoading = false;

  bool get _isEditing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
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
        _titleController.text = todo.title;
        _descController.text = todo.description ?? '';
        _category = todo.category;
        _priority = todo.priority;
        _dueDate = todo.dueDate;
        _createDate = todo.createdAt;
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final todo = TodoEntity(
        id: widget.editId,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        category: _category,
        priority: _priority,
        dueDate: _dueDate,
        createdAt: _createDate,
        updatedAt: now,
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
      if (!currentCats.contains(_category)) {
        catsNotifier.add(_category);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '已更新' : '已创建')),
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
                      child: Consumer(builder: (ctx, ref, _) {
                        final cats = ref.watch(todoCategoriesProvider).valueOrNull ?? ['生活', '工作'];
                        return Row(
                          children: cats.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildCategoryChoice(
                              label: cat,
                              icon: _categoryIcons[cat] ?? Icons.category,
                              color: _categoryColors[cat] ?? Colors.teal,
                              isSelected: _category == cat,
                              onTap: () => setState(() => _category = cat),
                            ),
                          )).toList(),
                        );
                      }),
                    ),
                    if (!(ref.watch(todoCategoriesProvider).valueOrNull ?? ['生活', '工作']).contains(_category))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Chip(
                          label: Text(_category),
                          avatar: const Icon(Icons.category, size: 16),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: '自定义分类（输入新名称）',
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
                    const SizedBox(height: 24),

                    // 优先级
                    Text('优先级',
                        style: Theme.of(context).textTheme.titleMedium),
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

                    // 创建日期
                    Text('创建日期',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickCreateDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_calendar, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              '${_createDate.year}-${_createDate.month.toString().padLeft(2, '0')}-${_createDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 截止日期
                    Text('截止日期',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
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
                              _dueDate != null
                                  ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                  : '点击选择日期',
                              style: TextStyle(
                                color: _dueDate != null
                                    ? null
                                    : Colors.grey,
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
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
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

  Future<void> _pickCreateDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _createDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _createDate = date);
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
