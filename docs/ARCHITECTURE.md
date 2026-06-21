# 项目结构与架构现状

最后更新：2026-06-21

本文只记录当前代码已经实现的结构和事实。未实现的设计想法统一放在 `ROADMAP.md` / `TODO.md`，避免把规划写成现状。

## 1. 项目定位

`寸积` 当前是一个 Flutter 本地优先个人工具，主打“时间的实体化”，已实现四个业务域：

| 业务域 | 当前形态 |
| --- | --- |
| 待办 | 任务、清单、子任务、软删除、归档、统计、周/月视图。 |
| 文玩/盘串 | 藏品档案、分类字段、照片、盘玩打卡、打卡对比、月历、趣味榜单；日志重型榜单已下沉到 DAO 批量聚合；估值功能已应用层下线，schema v8 遗留表/列暂留兼容。 |
| AI 复盘 | 独立复盘历史入口、对话式日报、日报详情、ISO 周报、离线模板生成器、OpenAI 兼容调用、文本/STT 输入边界、文玩盘玩分钟输入。 |
| 动态简历 | 三模板预览、长表单编辑、可见性开关、拖拽排序、图片导出分享。 |

## 2. 技术栈

来源：`pubspec.yaml`

| 层级 | 依赖 | 用途 |
| --- | --- | --- |
| App | Flutter / Dart SDK `^3.10.0` | 跨平台 UI。 |
| 状态管理 | `flutter_riverpod` | Provider / AsyncNotifier 状态流。 |
| 路由 | `go_router` | ShellRoute 和页面路由。 |
| 数据库 | `drift` + `sqlite3_flutter_libs` | 本地 SQLite ORM。 |
| 文件路径 | `path_provider` + `path` | 数据库、图片、配置文件路径。 |
| 网络 | `dio` | OpenAI 兼容 API 调用、连接检测。 |
| 通知 | `flutter_local_notifications` + `timezone` | 每日复盘/每周周报提醒。 |
| 图片 | `image_picker` + `gal` | 拍照/相册取图、保存到系统相册。 |
| 分享 | `share_plus` | 简历图片、文玩图片/对比图分享。 |
| 语音 | `speech_to_text` | 复盘页语音输入。 |
| 文件选择 | `file_picker` | JSON 备份导入导出。 |
| 国际化 | `flutter_localizations` + 手写 `AppLocalizations` | 中英文字符串入口。 |

## 3. 启动与路由

入口：`lib/main.dart` -> `AppBootstrap` -> `PersonalAssistantApp`

初始化流程：

1. `WidgetsFlutterBinding.ensureInitialized()`。
2. `ProviderScope` 启动 Riverpod。
3. `appInitializedProvider` 创建 Drift 数据库。
4. 从 `user_preferences` 加载主题。
5. 后台初始化 `NotificationService`。

当前底部导航只有 3 个 Tab：

```text
Tab 0: /collection    盘串
Tab 1: /todos         待办
Tab 2: /resume        简历
```

全屏路由：

```text
/settings
/review
/review/daily/new
/review/daily/edit/:date
/review/daily/:date
/review/weekly/:id
```

注意：`/review` 是独立全屏复盘历史入口，不进入底部导航。`RouteNames` 中仍保留 `/resume/preview`、`/resume/templates` 常量，但当前 `app_router.dart` 没有注册这些独立页面路由。

## 4. 目录结构

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router/
│   └── theme/
├── core/
│   ├── ai/
│   ├── database/
│   ├── models/
│   ├── notification_service.dart
│   └── utils/
├── features/
│   ├── ai_assistant/
│   ├── collection/
│   ├── resume/
│   ├── settings/
│   └── todo/
└── l10n/
```

Feature 内部约定：

```text
feature/
├── data/
│   ├── datasources/      # Drift 表、DAO
│   └── repositories/     # Repository 实现与 Provider
├── domain/
│   ├── entities/
│   └── repositories/
└── presentation/
    ├── pages/
    ├── providers/
    └── widgets/
```

## 5. 数据库现状

来源：`lib/core/database/app_database.dart`

当前 `schemaVersion = 9`，注册 14 张表：

| 表 | 当前用途 |
| --- | --- |
| `user_preferences` | 主题、语言、通知、AI 配置、复盘提醒、简历模板、待办分类 JSON。 |
| `collection_categories` | 文玩分类、子类型、分类专属字段、排序。 |
| `todo_lists` | 待办清单。 |
| `todos` | 待办任务、子任务、状态、标签、软删除、重复策略。 |
| `antique_items` | 文玩藏品档案。 |
| `valuation_records` | 遗留估值兼容表；应用层已下线，新备份不再导出估值历史。 |
| `patting_logs` | 文玩盘玩/打卡日志。 |
| `daily_reviews` | 每日复盘。 |
| `weekly_reports` | 每周周报。 |
| `resume_profile` | 简历个人资料。 |
| `work_experiences` | 工作经历。 |
| `educations` | 教育经历。 |
| `skill_items` | 技能项。 |
| `project_experiences` | 项目经历。 |

迁移历史：

| 版本 | 代码迁移 |
| --- | --- |
| `<2` | 为 `antique_items` 增加 `category_metadata`。 |
| `<3` | 创建 `collection_categories`。 |
| `<4` | 为 `user_preferences` 增加 `todo_categories`。 |
| `<5` | 为 `todos` 增加 `deleted_at`。 |
| `<6` | 创建 `todo_lists`，并为 `todos` 增加 `list_id`、`parent_id`、`recurrence_rule`。 |
| `<7` | 为待办树查询、清单筛选、活跃任务统计和今日完成统计补充 `todos` 索引。 |
| `<8` | 为文玩榜单与日期区间统计补充 `patting_logs(item_id, date DESC)`、`patting_logs(date, item_id)` 索引。 |
| `<9` | 为 `user_preferences` 增加 `ai_config`，保存非敏感 LLM 策略 JSON。 |

## 6. 当前模块依赖流

```text
Settings
  -> UserPreferencesDao / AppSettingsPersistence / NotificationService
  -> AIConfigProvider

Todo
  -> TodoRepository -> TodoDao -> todos / todo_lists
  -> Review providers 用于首页复盘卡片

Collection
  -> AntiqueRepository -> AntiqueDao
  -> antique_items / patting_logs
  -> AppSettingsPersistence 保存翻牌配置和网格列数

AI Assistant
  -> ReviewRepository -> ReviewDao -> daily_reviews / weekly_reports
  -> AIService: OfflineReviewGenerator 或 OpenAIService
  -> TodoRepository 读取今日已完成任务标题

Resume
  -> ResumeRepository -> ResumeDao
  -> resume_profile / work_experiences / educations / skill_items / project_experiences
```

## 7. 平台现状

| 平台 | 代码事实 |
| --- | --- |
| Android | `compileSdk = 36`，`minSdk = 24`，`targetSdk = 36`，debug 签名用于 release。 |
| Web | Flutter 默认 Web 壳，manifest 仍是默认描述。 |
| Windows | 默认 Flutter Windows runner，窗口标题 `寸积`，初始 1280x720。 |

## 8. 测试现状

当前已有 DAO、备份恢复、路由和数据库迁移等专项测试；`test/app_test.dart` 和 `test/widget_test.dart` 仍是占位测试，只断言 `true`。文玩榜单聚合由 `test/antique_dao_test.dart` 覆盖，schema v7/v8 索引迁移由 `test/app_database_migration_test.dart` 覆盖。
