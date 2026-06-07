/// 待办分类管理 Provider。
///
/// 支持 CRUD：添加、删除自定义分类。初始分类：生活、工作。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 默认初始分类
const List<String> _initialCategories = ['生活', '工作'];

/// 分类管理 Provider
final todoCategoriesProvider =
    StateNotifierProvider<TodoCategoriesNotifier, List<String>>((ref) {
  return TodoCategoriesNotifier();
});

class TodoCategoriesNotifier extends StateNotifier<List<String>> {
  TodoCategoriesNotifier() : super([..._initialCategories]);

  void add(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    state = [...state, trimmed];
  }

  void remove(String category) {
    if (_initialCategories.contains(category)) return; // 不可删除默认分类
    state = state.where((c) => c != category).toList();
  }

  void rename(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    state = state.map((c) => c == oldName ? trimmed : c).toList();
  }
}
