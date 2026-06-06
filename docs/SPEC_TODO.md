# 待办清单模块 — 详细规格说明

## 一、数据模型

### 1.1 drift 表定义

```dart
// features/todo/data/datasources/todos_table.dart
import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class Todos extends Table {
  @override
  String get tableName => 'todos';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('life'))();   // life | work
  IntColumn get priority => integer().withDefault(const Constant(3))();     // 1-5
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();  // pending | in_progress | done | cancelled
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();

  // 生命周期追踪字段
  DateTimeColumn get startedAt => dateTime().nullable()();        // 开始执行时间
  DateTimeColumn get completedAt => dateTime().nullable()();      // 完成时间
  DateTimeColumn get cancelledAt => dateTime().nullable()();      // 放弃时间
  IntColumn get actualMinutes => integer().nullable()();          // 实际耗时（分钟）
  IntColumn get delayCount => integer().withDefault(const Constant(0))(); // 延期次数

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();
}
```

### 1.2 状态机

```
pending ──► in_progress ──► done
  │                            │
  └─────► cancelled ◄──────────┘
```

- **pending**：新建待办，尚未开始
- **in_progress**：用户标记开始执行（记录 `startedAt`）
- **done**：用户标记完成（记录 `completedAt` + 自动计算 `actualMinutes`）
- **cancelled**：用户放弃该任务（记录 `cancelledAt`）

### 1.3 延期计算逻辑

- 如果 `dueDate` 不为空且 `completedAt > dueDate`，则判定为延期
- 每次待办进入 `in_progress` 但未在 `dueDate` 前完成，`delayCount` 增加

## 二、功能列表

### 2.1 列表与视图

| 视图 | 说明 |
|------|------|
| **列表视图** | 按分类 Tab 切换（生活/工作），每项显示标题、截止日期、优先级星级、状态 |
| **四象限看板** | 重要-紧急矩阵：横轴紧急（dueDate），纵轴重要（priority），支持拖拽变更优先级 |
| **日历视图** | 月历，每天显示待办密度圆点，点击日期查看当日待办 |

### 2.2 操作

| 操作 | 交互方式 | 说明 |
|------|----------|------|
| 新建 | FAB | 弹出表单页面 |
| 编辑 | 点击列表项 | 进入编辑页面 |
| 完成 | 左滑 | 状态 → done，记录 completedAt，Undo Snackbar |
| 删除 | 右滑 | 状态 → cancelled，Undo Snackbar |
| 标记星标 | 点击星标图标 | 在列表顶部/单独分区展示 |
| 拖拽排序 | 长按后拖拽 | 改变列表顺序（本地排序） |

### 2.3 表单字段

| 字段 | 类型 | 说明 |
|------|------|------|
| 标题 | TextField | 必填，最多 100 字 |
| 描述 | TextField (multiline) | 可选 |
| 分类 | SegmentedButton | 生活 / 工作 |
| 优先级 | Star Rating (1-5) | 默认 3 |
| 截止日期 | DatePicker + TimePicker | 可选 |
| 标签 | ChipInput | 自由输入标签，自动补全历史标签 |

### 2.4 统计仪表盘

| 卡片 | 内容 |
|------|------|
| 今日进度 | 已完成 / 总数，环形进度条 |
| 本周完成率 | 本周完成 / 总数，百分比 |
| 拖延率 | 延期任务 / 已完成任务 |
| 待办分布 | 按优先级分组的柱状图 |

## 三、数据访问层（DAO）

```dart
// 核心接口
class TodoDao {
  // 基础 CRUD
  Future<Todo> insert(TodosCompanion entry);
  Future<Todo> update(int id, TodosCompanion entry);
  Future<void> delete(int id);
  Future<Todo?> getById(int id);
  Future<List<Todo>> getAll();

  // 查询
  Future<List<Todo>> getByCategory(String category);           // life / work
  Future<List<Todo>> getByStatus(String status);               // pending / in_progress / done
  Future<List<Todo>> getByDateRange(DateTime start, DateTime end);
  Future<List<Todo>> search(String keyword);                   // 全文搜索 title + description

  // 统计
  Future<int> countTodayCompleted();
  Future<int> countTotal();
  Future<double> weeklyCompletionRate();
  Future<double> delayRate();
}
```

## 四、通知策略

| 触发条件 | 通知内容 | 提前时间 |
|----------|----------|----------|
| 截止日期临近 | "任务「xxx」即将截止" | 30 分钟前 |
| 每晚提醒复盘 | "今天还有 X 个待办未完成，来复盘吧" | 21:00 |
| 每日开始 | "早安！今天有 X 个待办等着你" | 08:00 |

## 五、与其他模块联动

- **AI 复盘模块**：读取当日 `completed` 状态的待办，传入 AI 作为上下文
- **统计看板**：数据同时展示在主屏幕的「今日概览」卡片中
