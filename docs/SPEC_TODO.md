# 待办与任务树规格

最后更新：2026-06-20

待办模块是个人 AI 助手的核心行动数据源。它既承担日常任务管理，也为深夜日报、周报和简历高光提供结构化输入。

## 1. 当前数据模型

当前已存在 `todo_lists` 与 `todos` 两张表，`todos.parent_id` 支持任务自关联。

### `todo_lists`

| 字段 | 说明 |
| --- | --- |
| `id` | 主键 |
| `name` | 清单名称，1-50 字 |
| `category` | 所属分类，如生活、工作 |
| `created_at` | 创建时间 |

### `todos`

| 字段 | 说明 |
| --- | --- |
| `id` | 主键 |
| `title` | 标题 |
| `list_id` | 所属清单，可空 |
| `parent_id` | 父任务 ID，可空 |
| `recurrence_rule` | 重复策略，可空，支持 daily / weekly / monthly |
| `description` | 描述 |
| `category` | 分类 |
| `priority` | 优先级，默认 3 |
| `due_date` | 截止时间，可空 |
| `status` | pending / in_progress / done / cancelled |
| `tags` | 标签列表 |
| `is_starred` | 星标 |
| `started_at` | 开始时间 |
| `completed_at` | 完成时间 |
| `cancelled_at` | 取消时间 |
| `deleted_at` | 软删除时间 |
| `actual_minutes` | 实际耗时 |
| `delay_count` | 延期次数 |
| `created_at` / `updated_at` | 时间戳 |

## 2. 创建与输入限制

| 项 | 规则 |
| --- | --- |
| 标题 | 必填，最多 100 字。 |
| 描述 | 可选，最多 1000 字。 |
| `startedAt` | 常规待办创建时默认当前时间。 |
| `dueDate` | 可选，不填时仍可进入今日滚存。 |
| 优先级 | 1-5，默认 3。 |
| 标签 | 用于高光、简历素材、分类检索。 |

## 3. 四层任务结构

目标结构为：

```text
长期维度 / 分类
  -> 清单 todo_lists
    -> 父任务 todos(parent_id == null)
      -> 子任务 todos(parent_id == parent.id)
```

当前代码已具备清单表和自关联字段，但 UI 与 Repository 仍需继续收敛到四层控制流。

## 4. 状态机

```text
pending -> in_progress -> done
   |             |          |
   +-------------+----------> cancelled
```

| 状态 | 说明 |
| --- | --- |
| pending | 已创建，尚未开始。 |
| in_progress | 已开始，记录 `started_at`。 |
| done | 已完成，记录 `completed_at`。 |
| cancelled | 已取消，记录 `cancelled_at`。 |

## 5. 级联规则

| 场景 | 规则 |
| --- | --- |
| 父任务完成 | DAO 必须将所有未删除子任务同步标记为 done。 |
| 父任务取消 | DAO 必须将所有未删除子任务同步标记为 cancelled。 |
| 父任务软删除 | 父任务 `deleted_at != null` 后，其子任务也必须软删除。 |
| 查询展示 | 已删除父任务与其子任务在所有常规查询中不可见。 |

当前 `TodoDao.cascadeStatus()` 与 `cascadeDelete()` 已体现该方向。后续要补充更完整的事务边界与测试。

## 6. 树状组装规范

Repository 向 Riverpod 状态层吐数据时，不允许直接返回关系型数据库打平数组。目标流程为：

```dart
// Step 1: 查询 parentId == null 且符合展示条件的父任务。
// Step 2: 提取父任务 ID 集合，用一次 IN 查询批量捞出子任务。
// Step 3: 在 Dart 内存中按 parentId 分组，将子任务注入父任务 subtasks。
```

当前 DAO 的 `getTree()` 能返回树形实体，但内部仍是逐父任务查询子任务。代码阶段需优化为批量 IN 查询，避免 N+1 查询。

## 7. 今日展示与滚存

跨天未完成任务不改写物理创建时间，展示层通过只读计算属性 `displayDate` 无损滚存。

| 逻辑 | 说明 |
| --- | --- |
| 已完成 | 展示日期取 `completed_at`。 |
| 已取消 | 展示日期取 `cancelled_at`。 |
| 活跃任务 | 若 `started_at` 早于今天，`displayDate` 视为今天。 |
| 新任务 | 展示日期取 `started_at` 或 `created_at`。 |

## 8. 仪表盘统计公式

今日总数必须只统计父任务，子任务只作为父任务卡片内部进度，不计入主仪表盘分母。

```text
今日总数 =
  今天新创建的父任务
  ∪ 历史创建且至今未完成、未取消、未删除的父任务
```

Drift 查询必须包含：

```sql
WHERE parent_id IS NULL
```

当前 `countTodayTotal()`、`countTodayCompleted()` 等统计已按父任务约束推进，后续需用测试锁死。

## 9. 与教练式对话联动

当用户勾选高优任务完成时，系统可触发单轮追问：

| 条件 | 行为 |
| --- | --- |
| 父任务优先级高 | 弹出一次轻量追问。 |
| 用户回答 | 保存为当天对话素材。 |
| 用户跳过 | 不继续追问。 |
| 当日对话已达 15 轮 | 不再触发云端 AI，只保存离线便签。 |

追问目标是捕获突破、卡点、经验教训，而不是发散闲聊。

## 10. 质量要求

1. 任何任务查询默认排除 `deleted_at != null`。
2. 子任务状态更新必须可追踪，不允许出现父任务完成但子任务仍 pending 的常规状态。
3. 仪表盘主指标只统计父任务。
4. `displayDate` 只能是计算属性，不反写历史创建时间。
5. 高光标签如 `#简历素材` 只能在模型结构化判定后写入，且需要用户可撤销。
