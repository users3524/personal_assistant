/// 待办模块数据仓库接口。
library;

import '../entities/todo_entity.dart';

abstract class TodoRepository {
  // ===== 清单 =====
  Future<List<TodoListEntity>> getLists();
  Future<TodoListEntity> saveList(TodoListEntity list);
  Future<void> deleteList(int id);

  // ===== CRUD =====
  Future<TodoEntity> create(TodoEntity todo);
  Future<TodoEntity?> getById(int id);
  Future<List<TodoEntity>> getAll();
  Future<List<TodoEntity>> getTree();
  Future<TodoEntity> update(TodoEntity todo);

  // ===== 子任务 =====
  Future<TodoEntity> addSubtask(int parentId, TodoEntity subtask);
  Future<List<TodoEntity>> getSubtasks(int parentId);

  // ===== 删除与恢复 =====
  Future<void> delete(int id);
  Future<void> cascadeDelete(int id);
  Future<void> restore(int id);
  Future<void> hardDelete(int id);

  // ===== 重复策略 =====
  Future<TodoEntity?> completeRecurring(int id);

  // ===== 查询 =====
  Future<List<TodoEntity>> getByCategory(String category);
  Future<List<TodoEntity>> getByStatus(TodoStatus status);
  Future<List<TodoEntity>> getByCategoryAndStatus(String category, TodoStatus status);
  Future<List<TodoEntity>> getByDateRange(DateTime start, DateTime end);
  Future<List<TodoEntity>> search(String keyword);
  Future<List<TodoEntity>> getStarred();
  Future<List<TodoEntity>> getToday();
  Future<List<TodoEntity>> getActive();
  Future<List<TodoEntity>> getOverdue();
  Future<List<TodoEntity>> getArchived();
  Future<List<TodoEntity>> getTrashed();

  // ===== 批量 =====
  Future<void> softClearCompleted();
  Future<void> emptyTrash();

  // ===== 统计 =====
  Future<int> countTodayCompleted();
  Future<int> countTodayTotal();
  Future<double> weeklyCompletionRate();
  Future<double> delayRate();

  // ===== 状态操作 =====
  Future<TodoEntity> start(int id);
  Future<TodoEntity> reopen(int id);
  Future<TodoEntity> complete(int id);
  Future<TodoEntity> cancel(int id);
  Future<void> cascadeStatus(int id, TodoStatus status);
  Future<TodoEntity> toggleStar(int id);
}
