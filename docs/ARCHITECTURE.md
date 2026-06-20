# 项目结构与架构设计

最后更新：2026-06-20

本项目是一个本地优先的个人 AI 助手，当前代码形态为 Flutter + Riverpod + Drift。现阶段先完成产品功能设计与模块边界收敛，不改动业务代码。

## 1. 当前产品定位

个人助手不是纯聊天产品，而是一个以本地数据为核心的日常记录系统：

| 目标 | 说明 |
| --- | --- |
| 本地优先 | 待办、文玩记录、复盘、简历数据默认写入本地 SQLite。 |
| 低成本 AI | 白天只做轻量捕获，深夜集中调用高算力模型生成日报。 |
| 长期记忆 | 深度日报进入向量记忆，用于周报、规划纠偏和简历素材沉淀。 |
| 文玩记录保留 | 藏品、盘玩打卡、照片、估值、趣味榜单继续作为一等功能保留。 |
| 简历资产化 | 日常高光通过 STAR 规则转为项目经历与简历素材。 |

## 2. 当前主入口与路由

当前 `MainShell` 是 3 个底部 Tab，AI 复盘与设置页面以全屏路由进入。

```text
/collection                 -> AntiqueListPage
/collection/new             -> AntiqueFormPage
/collection/:id             -> AntiqueDetailPage
/collection/:id/edit        -> AntiqueFormPage(editId)

/todos                      -> TodoListPage
/todos/new                  -> TodoFormPage
/todos/:id                  -> TodoDetailPage
/todos/:id/edit             -> TodoFormPage(editId)

/resume                     -> ResumeHomePage

/settings                   -> SettingsPage

/review/daily/new           -> DailyReviewChatPage
/review/daily/edit/:date    -> DailyReviewChatPage(dateStr)
/review/daily/:date         -> DailyReviewDetailPage
/review/weekly/:id          -> WeeklyReportPage
```

## 3. 当前目录结构

```text
personal_assistant/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router/
│   │   │   ├── app_router.dart
│   │   │   └── route_names.dart
│   │   └── theme/
│   │       ├── app_colors.dart
│   │       ├── app_text_styles.dart
│   │       └── app_theme.dart
│   ├── core/
│   │   ├── ai/
│   │   │   ├── ai_provider.dart
│   │   │   ├── ai_prompts.dart
│   │   │   ├── ai_service.dart
│   │   │   ├── offline_review_generator.dart
│   │   │   └── openai_service.dart
│   │   ├── database/
│   │   │   ├── app_database.dart
│   │   │   ├── app_database_provider.dart
│   │   │   ├── app_settings_persistence.dart
│   │   │   ├── backup_service.dart
│   │   │   ├── converters/
│   │   │   └── tables/
│   │   ├── models/
│   │   ├── notification_service.dart
│   │   └── utils/
│   ├── features/
│   │   ├── ai_assistant/
│   │   ├── collection/
│   │   ├── resume/
│   │   ├── settings/
│   │   └── todo/
│   └── l10n/
├── docs/
├── test/
├── android/
├── web/
├── windows/
├── pubspec.yaml
└── build_and_run.bat
```

## 4. Feature 分层约定

每个业务模块沿用 feature-first + Clean Architecture 的三层结构。

```text
feature/
├── data/
│   ├── datasources/      # Drift 表、DAO、本地数据源
│   └── repositories/     # Repository 实现
├── domain/
│   ├── entities/         # 纯 Dart 实体
│   └── repositories/     # Repository 抽象接口
└── presentation/
    ├── pages/
    ├── providers/
    └── widgets/
```

## 5. 技术栈现状

| 层级 | 当前依赖 | 状态 |
| --- | --- | --- |
| UI | Flutter 3.x / Dart 3.10 | 已接入 |
| 状态管理 | flutter_riverpod 2.x | 已接入 |
| 路由 | go_router 14.x | 已接入 |
| 数据库 | drift 2.33 + sqlite3_flutter_libs | 已接入 |
| 网络 | dio 5.x | 已接入，用于 OpenAI 兼容 API |
| 图片 | image_picker, gal, path_provider | 已接入 |
| 语音 | speech_to_text | 已接入 |
| 文件选择 | file_picker | 已接入 |
| 分享 | share_plus | 已接入 |
| 图表 | fl_chart | 已接入，文玩估值/看板仍保留 |
| 本地通知 | flutter_local_notifications + timezone | 已接入 |

说明：PDF 导出与向量数据库属于后续功能设计目标，当前 `pubspec.yaml` 未固定相关实现依赖。

## 6. 数据库现状

当前 `AppDatabase.schemaVersion = 6`，共 14 张业务表。

| 表 | 用途 |
| --- | --- |
| `user_preferences` | 主题、AI 配置、通知、偏好设置 |
| `collection_categories` | 文玩分类、子类与分类字段配置 |
| `todo_lists` | 待办清单 |
| `todos` | 待办任务与子任务，自关联 `parent_id` |
| `antique_items` | 文玩藏品主表 |
| `valuation_records` | 文玩估值记录 |
| `patting_logs` | 文玩盘玩/打卡日志 |
| `daily_reviews` | 每日复盘 |
| `weekly_reports` | 每周复盘 |
| `resume_profile` | 简历个人信息 |
| `work_experiences` | 工作经历 |
| `educations` | 教育经历 |
| `skill_items` | 技能项 |
| `project_experiences` | 项目经历 |

## 7. Drift 迁移历史

| 版本 | 变更 |
| --- | --- |
| v2 | `antique_items.category_metadata` |
| v3 | 新增 `collection_categories` |
| v4 | `user_preferences.todo_categories` |
| v5 | `todos.deleted_at` |
| v6 | 新增 `todo_lists`，并为 `todos` 增加 `list_id`、`parent_id`、`recurrence_rule` |

## 8. 模块边界总览

| 模块 | 负责 | 禁止越界 |
| --- | --- | --- |
| 数据捕获与日常对话 | 任务、文玩打卡、习惯打卡、短对话、离线便签 | 白天不查历史日报、不做 RAG、不长轮聊天 |
| 深夜精炼与日报生成 | 打包当天数据，生成 Markdown 日报和高光判定 | 不在失败时无限重试，不上传超大原始流水账 |
| 长效记忆与人生罗盘 | 向量化日报、五维目标、周报纠偏 | 不允许新增第 6 个战略维度 |
| 高光摘取与简历生成 | 里程碑筛选、STAR 润色、项目经历沉淀 | 模型只产纯文本，不控制页面/PDF 样式 |
| 文玩记录 | 藏品、照片、盘玩日志、估值、榜单 | 不因 AI 改造而删除现有记录能力 |

## 9. 数据流

```text
白天：
  Todo / 文玩盘玩 / 习惯打卡 / 教练式短对话
      -> 本地 SQLite 原始素材

深夜：
  当日结构化数据 + 原始短文本
      -> 云端大模型结构化输出
      -> daily_reviews Markdown + 高光 JSON

长期：
  daily_reviews
      -> Embedding 向量切片
      -> 周报 / 人生罗盘纠偏 / 简历素材检索

简历：
  高光里程碑
      -> STAR 纯文本 bullet
      -> project_experiences / badges / keyDeliverables
```

## 10. 后续架构新增点

为了落地新规格，后续代码阶段需要新增或迁移的能力包括：

| 能力 | 建议落点 |
| --- | --- |
| 对话 turn 计数与离线便签 | `features/ai_assistant` + 新表 `chat_turns` |
| 习惯打卡 | 可独立 `features/habit`，或先并入 `ai_assistant/data_capture` |
| 深夜任务调度 | Android WorkManager 等后台任务封装 |
| 充电/Wi-Fi 条件检测 | 平台通道或成熟插件 |
| 结构化输出解析与重试 | `core/ai` 增加 JSON schema/validator |
| 向量存储 | 本地轻量向量库或 SQLite 扩展封装 |
| 人生罗盘 | 新表 `life_compass_goals` + 冷却校验 |
| 里程碑库 | 新表 `milestones`，并关联 Todo / 文玩 / 日报 / 简历 |
