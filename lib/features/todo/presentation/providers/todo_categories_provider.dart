/// 待办分类管理 Provider。
///
/// 支持 CRUD：添加、删除、重命名自定义分类。
/// 数据持久化到 user_preferences 表。
/// 初始分类：生活、工作。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/user_preferences_dao.dart';
import '../../../../core/database/app_database_provider.dart';

/// 默认初始分类（不可删除）
const List<String> _initialCategories = ['生活', '工作'];

/// 分类管理 Provider
final todoCategoriesProvider =
    AsyncNotifierProvider<TodoCategoriesNotifier, List<String>>(
  TodoCategoriesNotifier.new,
);

class TodoCategoriesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final db = await ref.watch(appDatabaseProvider.future);
    final dao = UserPreferencesDao(db);
    final saved = await dao.getTodoCategories();
    if (saved.isEmpty) {
      // 首次使用，保存默认分类
      await dao.setTodoCategories([..._initialCategories]);
      return [..._initialCategories];
    }
    return saved;
  }

  Future<void> _persist(List<String> categories) async {
    final db = await ref.read(appDatabaseProvider.future);
    final dao = UserPreferencesDao(db);
    await dao.setTodoCategories(categories);
  }

  Future<void> add(String category) async {
    final trimmed = category.trim();
    final current = [...state.valueOrNull ?? _initialCategories];
    if (trimmed.isEmpty || current.contains(trimmed)) return;
    final updated = [...current, trimmed];
    await _persist(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> remove(String category) async {
    final current = [...state.valueOrNull ?? _initialCategories];
    if (_initialCategories.contains(category)) return; // 不可删除默认分类
    final updated = current.where((c) => c != category).toList();
    await _persist(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> rename(String oldName, String newName) async {
    final trimmed = newName.trim();
    final current = [...state.valueOrNull ?? _initialCategories];
    if (trimmed.isEmpty || current.contains(trimmed)) return;
    final updated = current.map((c) => c == oldName ? trimmed : c).toList();
    await _persist(updated);
    state = AsyncValue.data(updated);
  }

  /// 检查某个分类下有多少待办事项
  Future<int> countTodosUsingCategory(String category) async {
    final db = await ref.read(appDatabaseProvider.future);
    final all = await db.select(db.todos).get();
    return all.where((t) => t.category == category).length;
  }
}
