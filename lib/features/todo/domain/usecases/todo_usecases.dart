/// 待办模块 Use Cases。
///
/// 提供列表查询的 Use Case Provider。
/// 统计和操作相关的 Provider 定义在 presentation/providers/ 中。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/todo_repository_impl.dart';
import '../entities/todo_entity.dart';

/// 所有待办列表
final allTodosProvider = FutureProvider<List<TodoEntity>>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getAll();
  });
});

/// 按分类的待办列表
final todosByCategoryProvider2 =
    FutureProvider.family<List<TodoEntity>, String>((ref, category) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getByCategory(category);
  });
});

/// 搜索待办
final searchTodosProvider2 =
    FutureProvider.family<List<TodoEntity>, String>((ref, keyword) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.search(keyword);
  });
});

/// 今日待办
final todayTodosProvider = FutureProvider<List<TodoEntity>>((ref) {
  return ref.watch(todoRepositoryProvider.future).then((repo) {
    return repo.getToday();
  });
});
