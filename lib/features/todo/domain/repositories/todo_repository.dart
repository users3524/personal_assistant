/// 待办模块数据仓库接口。
///
/// 定义领域层需要的数据操作契约，数据层实现此接口。
library;

import '../entities/todo_entity.dart';

abstract class TodoRepository {
  // ===== 基础 CRUD =====

  /// 创建待办
  Future<TodoEntity> create(TodoEntity todo);

  /// 根据 ID 查询（含已删除）
  Future<TodoEntity?> getById(int id);

  /// 查询所有未删除待办
  Future<List<TodoEntity>> getAll();

  /// 更新待办
  Future<TodoEntity> update(TodoEntity todo);

  // ===== 删除与恢复 =====

  /// 软删除（移入回收站）
  Future<void> delete(int id);

  /// 恢复软删除
  Future<void> restore(int id);

  /// 永久删除
  Future<void> hardDelete(int id);

  // ===== 查询 =====

  /// 按分类查询
  Future<List<TodoEntity>> getByCategory(String category);

  /// 按状态查询
  Future<List<TodoEntity>> getByStatus(TodoStatus status);

  /// 按分类+状态查询
  Future<List<TodoEntity>> getByCategoryAndStatus(
    String category,
    TodoStatus status,
  );

  /// 按截止日期范围查询
  Future<List<TodoEntity>> getByDateRange(DateTime start, DateTime end);

  /// 搜索（标题+描述全文搜索）
  Future<List<TodoEntity>> search(String keyword);

  /// 获取星标任务
  Future<List<TodoEntity>> getStarred();

  /// 获取今日待办（截止日期为今天且未完成）
  Future<List<TodoEntity>> getToday();

  /// 活跃待办（未完成、未逾期）
  Future<List<TodoEntity>> getActive();

  /// 逾期待办（未完成、截止日期已过）
  Future<List<TodoEntity>> getOverdue();

  /// 归档（已完成或已取消）
  Future<List<TodoEntity>> getArchived();

  /// 回收站（已软删除）
  Future<List<TodoEntity>> getTrashed();

  // ===== 批量操作 =====

  /// 已完成任务移至回收站
  Future<void> softClearCompleted();

  /// 清空回收站
  Future<void> emptyTrash();

  // ===== 统计 =====

  /// 今日完成数
  Future<int> countTodayCompleted();

  /// 今日待办总数
  Future<int> countTodayTotal();

  /// 本周完成率
  Future<double> weeklyCompletionRate();

  /// 拖延率
  Future<double> delayRate();

  // ===== 状态操作 =====

  /// 标记为进行中
  Future<TodoEntity> start(int id);

  /// 恢复为待办（从已完成/已取消/已删除状态回退）
  Future<TodoEntity> reopen(int id);

  /// 标记为完成
  Future<TodoEntity> complete(int id);

  /// 标记为取消
  Future<TodoEntity> cancel(int id);

  /// 切换星标
  Future<TodoEntity> toggleStar(int id);
}
