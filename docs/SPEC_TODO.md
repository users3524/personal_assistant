# 待办模块规格

最后更新：2026-06-20

本文按当前待办代码记录，不包含未实现的 AI 教练、人生罗盘绑定等规划。

## 0. 当前口径与未来规划边界

待办模块当前已经有分类、清单表、父子任务、软删除、周/月视图和统计，但还没有完整的“四层行动空间”产品闭环。后续设计可以按以下边界推进：

| 层级 | 当前状态 | 后续方向 |
| --- | --- | --- |
| 分类 | `user_preferences.todo_categories` JSON，默认“生活/工作”。 | 继续作为顶层筛选和清单归类入口。 |
| 清单 | `todo_lists` 表和 DAO 已存在，UI 使用有限。 | 补完整清单选择、筛选、备份导入导出。 |
| 父任务 | `todos.parent_id IS NULL`，参与主列表和统计。 | 继续作为仪表盘分母单位；未来可绑定人生罗盘维度。 |
| 子任务 | `todos.parent_id` 自关联，详情页可添加。 | 只展示父任务内部进度，不进入主仪表盘分母。 |

注意：人生罗盘、AI 教练式追问和高光打标当前都未实现，不能写成当前功能。

## 1. 当前页面与入口

| 路由 | 页面 | 当前功能 |
| --- | --- | --- |
| `/todos` | `TodoListPage` | 周/月视图、今日任务、统计卡、复盘卡、历史日报/周报入口、归档入口。 |
| `/todos/new` | `TodoFormPage` | 新建待办。 |
| `/todos/:id` | `TodoDetailPage` | 详情、状态操作、子任务、编辑/删除。 |
| `/todos/:id/edit` | `TodoFormPage(editId)` | 编辑待办。 |

## 2. 数据表

### `todo_lists`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `name` | 清单名称，1-50 字。 |
| `category` | 清单分类。 |
| `created_at` | 创建时间。 |

DAO 已支持清单 CRUD，但当前主要 UI 仍围绕任务分类和任务树展开。

### `todos`

| 字段 | 当前用途 |
| --- | --- |
| `id` | 主键。 |
| `title` | 标题。 |
| `list_id` | 所属清单，可空；物理外键指向 `todo_lists.id`，删除清单时 Drift 配置为 `onDelete: setNull`，任务本身不会被级联删除。 |
| `parent_id` | 父任务 ID，可空；为空表示父任务。物理外键自关联 `todos.id`，硬删除父任务时数据库可级联硬删除子任务；当前产品的软删除隐藏仍由 DAO 写入 `deleted_at` 完成。 |
| `recurrence_rule` | 重复策略：`daily` / `weekly` / `monthly` 或空。 |
| `description` | 描述。 |
| `category` | 分类，默认旧值 `life`，DAO 会归一为“生活”。 |
| `priority` | 优先级，默认 3。 |
| `due_date` | 截止时间。 |
| `status` | `pending` / `in_progress` / `done` / `cancelled`。 |
| `tags` | 标签列表，`StringListConverter`。 |
| `is_starred` | 星标。 |
| `started_at` | 开始时间。 |
| `completed_at` | 完成时间。 |
| `cancelled_at` | 取消时间。 |
| `deleted_at` | 软删除时间。 |
| `actual_minutes` | 实际耗时分钟。 |
| `delay_count` | 延期次数。 |
| `created_at` / `updated_at` | 时间戳。 |

### 后续索引草案

当前表定义没有显式声明这些索引。若后续任务量增大，可考虑在 Drift 迁移中补充：

| 索引 | 用途 |
| --- | --- |
| `todos(parent_id)` | 加速父子任务批量组装。 |
| `todos(list_id)` | 加速清单视图筛选。 |
| `todos(deleted_at, status, due_date)` | 加速活跃任务和滚存统计查询。 |
| `todos(parent_id, deleted_at)` | 加速子任务查询并过滤软删除。 |

索引需要结合实际查询和 SQLite explain 结果验证，避免过早增加写入成本。

## 3. 当前领域逻辑

来源：`TodoEntity`

| 逻辑 | 当前实现 |
| --- | --- |
| 状态枚举 | `pending`、`inProgress`、`done`、`cancelled`。 |
| 活跃判断 | pending/inProgress 且未软删除。 |
| 逾期判断 | 未完成/未取消/未删除，且 `dueDate` 或 `startedAt` 日期早于今天。 |
| 滚存展示 | `displayDate` 对活跃历史任务返回今天；不反写数据库。 |
| 今日展示 | `shouldShowInToday` 基于 `displayDate` 是否为今天。 |
| 父子判断 | `parentId == null` 为父任务。 |
| 子任务进度 | `done` 子任务数 / 子任务总数。 |

## 4. 当前 DAO 与 Repository

| 能力 | 当前实现 |
| --- | --- |
| 清单 | `getLists`、`saveList`、`deleteList`。 |
| 树查询 | `getTree()` 查询父任务后逐个 `_hydrateTree()` 查询子任务。 |
| 今日任务 | `getToday()` / `getTodayTree()` 基于实体计算过滤。 |
| 子任务 | `addSubtask()`、`getSubtasks()`。 |
| 级联状态 | `cascadeStatus()` 更新父任务和直接子任务。 |
| 软删除 | `softDelete()` -> `cascadeDelete()`，父任务和直接子任务写入 `deletedAt`。 |
| 恢复 | `restore()` 只恢复指定任务。 |
| 硬删除 | `hardDelete()`。 |
| 重复任务 | `completeRecurring()` 完成当前任务并创建下一周期副本。 |
| 查询 | 按分类、状态、分类+状态、日期范围、搜索、星标、活跃、逾期、归档、回收站。 |
| 批量 | `softClearCompleted()`、`emptyTrash()`。 |
| 统计 | 今日完成数、今日总数、本周完成率、拖延率。 |

注意：当前树查询存在 N+1 查询模式，尚未改成父任务 + 子任务 IN 批量查询。当前实现只装配直接子任务，不是无限深度递归树。

后续批量化方向：

1. 单次查询所有 `parentId IS NULL` 且未删除的父任务。
2. 提取父任务 ID 列表，使用一次 `IN` 查询拉取全部直接子任务。
3. 在 Dart 内存中按 `parentId` 分组，再注入父任务实体。
4. 为父任务为空、子任务软删除、父任务状态级联场景补测试。

未来实现时应优先在 DAO 层提供批量查询方法，例如 `getRootParents()` 和 `getChildrenByParentIds(parentIds)`；Repository 只负责内存组装，避免 UI/Provider 直接处理扁平行。

## 5. 当前状态操作

来源：`TodoRepositoryImpl`

| 操作 | 当前实现 |
| --- | --- |
| 开始 | 状态改为 `inProgress`，写入当前 `startedAt`。 |
| 完成 | 非重复任务调用 `cascadeStatus(done)`，写入 `completedAt`、`actualMinutes`、可能增加 `delayCount`。 |
| 完成重复任务 | 调用 `completeRecurring()` 归档当前并创建下一周期任务。 |
| 取消 | 调用 `cascadeStatus(cancelled)`，写入 `cancelledAt`。 |
| 重新打开 | 状态改为 `pending`，但当前 `copyWith` 不能显式置空 `completedAt`/`cancelledAt`。 |
| 星标 | 反转 `isStarred`。 |
| 删除 | 软删除。 |

后续修复：`TodoEntity.copyWith` 当前无法区分“未传值”和“显式传 null”，导致重新打开任务时难以清空 `completedAt` / `cancelledAt`，重复任务创建下一周期副本时也可能继承旧的完成时间、取消时间或实际耗时。可选方案包括 `Value<T?>` 包装、哨兵对象或独立 update command；选型后需要在实体和 Repository 中统一使用。若选择 `Value<T?>`，要注意它来自 Drift，不应让 domain 层在没有取舍的情况下被 ORM 类型污染。

级联状态和软删除后续应使用 Drift `transaction` 包裹，保证父任务、直接子任务以及未来的多态高光关联清理一致提交。当前 `cascadeStatus()` 和 `cascadeDelete()` 是连续 SQL 调用，尚未事务化。

## 6. 当前列表页功能

来源：`TodoListPage`

| 功能 | 当前实现 |
| --- | --- |
| 周/月切换 | AppBar 按钮切换 `CalendarView.week` / `month`。 |
| 周视图 | 7 天横向日期格，点击选择日期。 |
| 月视图 | 月历网格，显示日报记录标记。 |
| 今日统计 | 周视图展示 `TodoStatsCard`。 |
| 任务列表 | 父任务 + 缩进子任务展平展示；未完成在前，已完成分组。 |
| 滑动操作 | 右滑切换完成/重新打开，左滑乐观软删除。 |
| 复盘卡片 | 周视图底部展示今日复盘状态和本周周报入口。 |
| 历史查看 | 月视图底部按钮打开日报/周报历史 BottomSheet。 |
| 归档页 | AppBar 归档按钮进入已完成/已取消历史归档。 |

## 7. 当前表单功能

来源：`TodoFormPage`

| 字段 | 当前实现 |
| --- | --- |
| 标题 | 必填输入。 |
| 描述 | 多行输入。 |
| 分类 | 来自 `todoCategoriesProvider`，默认“生活/工作”，可自定义。 |
| 优先级 | 1-5 星。 |
| 开始时间 | 必填，默认当前时间。 |
| 截止日期 | 可选。 |
| 标签/清单/重复 | 表结构支持标签和重复，表单实际以当前页面代码为准，清单 UI 使用有限。 |

## 8. 当前详情页功能

来源：`TodoDetailPage`

| 功能 | 当前实现 |
| --- | --- |
| 基础信息 | 描述、分类、优先级、标签、时间信息。 |
| 状态按钮 | 开始执行、标记完成、放弃。 |
| 菜单 | 编辑、添加子任务、删除。 |
| 子任务 | 弹窗输入子任务名称，默认继承父任务分类、优先级、开始时间。 |
| 子任务展示 | 显示完成数/总数和进度条。 |

## 9. 当前统计口径

| 指标 | 当前实现 |
| --- | --- |
| 今日完成数 | `status = done` 且 `completedAt` 在今天，且 `parentId IS NULL`。 |
| 今日总数 | 今日完成父任务数 + 当前活跃且 `shouldShowInToday` 的父任务数。 |
| 本周完成率 | 本周创建的未删除父任务中 `status == done` 的比例。 |
| 拖延率 | 已完成父任务中 `completedAt > dueDate` 的比例。 |

### 后续统计校准目标

主仪表盘统计必须持续遵守两条边界：

1. 只统计根任务：所有主仪表盘分母查询都需要 `parentId IS NULL`。
2. 子任务只在父任务卡片内展示局部进度，例如 `2/4`，不进入大盘分母。

当前 `countTodayTotal()` 是“今日完成父任务数 + 当前活跃且 shouldShowInToday 的父任务数”，已排除子任务。若后续改成 SQL 聚合，应保持同等业务口径，并补覆盖滚存任务、今日完成任务、软删除任务和子任务的单元测试。

不要直接把今日分母简化为 `started_at in today OR status in (pending, in_progress)`。当前口径需要显式包含“今天完成的父任务”，否则昨天开始、今天完成的任务会从分母中漏掉；同时也要避免把历史已完成任务重新纳入今日分母。

## 10. 待办分类

来源：`todo_categories_provider.dart`

| 能力 | 当前实现 |
| --- | --- |
| 默认分类 | `todoCategoriesProvider` 首次初始化和不可删除默认项是“生活”“工作”；`TodoEntity.defaultCategories` 和表单图标仍保留“学习”“健康”等常量。 |
| 持久化 | `user_preferences.todo_categories` JSON。 |
| 添加 | 去重、去空。 |
| 删除 | 默认分类不可删除。 |
| 重命名 | 去重、去空。 |
| 使用统计 | 直接扫描 `todos.category`。 |

## 11. 备份恢复相关约束

待办模块依赖 `todo_lists`、`todos.list_id`、`todos.parent_id`、`todos.recurrence_rule` 和 `todos.deleted_at`。当前 `BackupService` 导入/导出仍有缺口，修复时需要注意：

1. 导出补齐 `todo_lists`。
2. 导入列清单补齐 `list_id`、`parent_id`、`recurrence_rule`、`deleted_at`。
3. 日期字段继续执行毫秒时间戳到 SQLite 秒级时间戳转换。
4. 恢复自关联父子任务时，要测试父任务/子任务插入顺序和外键约束。优先采用“先清单、再父任务、再子任务”的分阶段恢复；如确需临时关闭外键校验，必须限制在导入事务内，并在恢复后执行完整性校验，不能长期依赖全局 `PRAGMA foreign_keys = OFF`。
