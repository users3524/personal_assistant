# 项目结构与架构现状

最后更新：2026-06-21

本文记录当前代码事实，并给出重新整体审视后的架构判断。规划内容只描述方向，不把未实现能力写成当前功能。

## 1. 整体判断

`寸积` 已经从单纯的本地工具，演化成“本地优先的个人时间与证据系统”。现在最大的不合理点不是缺表，而是底座铺得比产品闭环更快：

| 观察 | 不合理处 | 新口径 |
| --- | --- | --- |
| AI 表、向量表、高光表已落地 | 用户还看不到深夜生成、高光确认、RAG 检索和简历投递闭环 | 下一阶段优先把已有底座接成可见工作流 |
| 待办、文玩、复盘、简历各自完整 | 模块之间连接主要靠少量入口和表关系，产品心智仍分散 | 以“每日复盘 -> 高光 -> 简历/长期记忆”为主线收敛 |
| WorkManager 已注册 | 回调当前不执行真实组包和写入，后台可靠性也天然不可承诺 | 先做前台补偿和手动执行，后台只作为机会性触发 |
| JSON 备份覆盖面变大 | 明文、全量覆盖导入、base64 图片会让备份风险和体积继续上升 | 备份需要 manifest、预检、校验、可选加密和更清晰的导入策略 |
| 文档曾以历史清单为目标 | 旧清单无法指导下一阶段产品闭环 | TODO 重置为下一阶段可交付任务 |

## 2. 项目定位

当前稳定定位：

> 本地优先记录生活与工作，把日常行动沉淀成复盘、证据和简历资产。

四个业务域仍保留，但优先级不同：

| 业务域 | 当前形态 | 下一阶段角色 |
| --- | --- | --- |
| 待办 | 任务、清单、子任务、软删除、归档、统计、周/月视图 | 行动来源，给复盘和高光提供事实 |
| 文玩/盘串 | 藏品、照片、盘玩打卡、月历、趣味榜单 | 情绪/兴趣素材来源，避免继续扩展估值方向 |
| AI 复盘 | 复盘入口、日报/周报、对话、月度日历、AI 边界控制 | 中枢模块，承接素材组包、生成、校准和高光抽取 |
| 动态简历 | 模板预览、编辑、图片导出 | 资产输出端，优先接 PDF 和高光投递 |

## 3. 技术栈

| 层级 | 依赖 | 用途 |
| --- | --- | --- |
| App | Flutter / Dart SDK `^3.10.0` | 跨平台 UI |
| 状态管理 | `flutter_riverpod` | Provider / AsyncNotifier 状态流 |
| 路由 | `go_router` | ShellRoute 和全屏页面路由 |
| 数据库 | `drift` + `sqlite3_flutter_libs` | 本地 SQLite ORM |
| 网络 | `dio` | OpenAI 兼容 API 调用 |
| 通知 | `flutter_local_notifications` + `timezone` | 每日复盘/每周周报提醒 |
| 后台调度 | `workmanager` | Android 机会性深夜任务注册 |
| 图片 | `image_picker` + `gal` | 拍照/相册取图、保存到系统相册 |
| 分享 | `share_plus` | 简历图片、文玩图片/对比图分享 |
| 语音 | `speech_to_text` | 复盘页语音输入 |
| 文件选择 | `file_picker` | JSON 备份导入导出 |
| 安全存储 | `flutter_secure_storage` | AI API Key 平台安全存储 |

## 4. 启动与路由

入口：`lib/main.dart` -> `AppBootstrap` -> `PersonalAssistantApp`

启动流程：

1. 初始化 Flutter 和 Riverpod。
2. 创建 Drift 数据库并加载偏好设置。
3. 后台初始化通知。
4. 后台运行 `ReviewCatchUpGuard`，确保昨日 `review_generation_jobs` 有待处理记录。
5. 通过 `AILogScheduler` 注册 Android WorkManager；桌面/Web 使用 No-Op。

底部导航：

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

`/review` 不进入底部 Tab。这个决定目前合理：复盘是中枢能力，但还没有足够高频的独立导航需求。等深夜生成、高光确认和复盘历史稳定后，再评估是否提升导航层级。

## 5. 目录结构

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

Feature 内部仍按 data/domain/presentation 分层。后续新增能力优先放在已有 feature 内，避免再引入横向“大 AI 模块”把依赖倒灌到所有页面。

## 6. 数据库现状

当前 `schemaVersion = 15`，注册 20 张表：

| 表 | 当前用途 |
| --- | --- |
| `user_preferences` | 主题、语言、通知、AI 配置、复盘提醒、简历模板、待办分类 JSON |
| `collection_categories` | 文玩分类、子类型、分类专属字段、排序 |
| `todo_lists` | 待办清单 |
| `todos` | 待办任务、子任务、状态、标签、软删除、重复策略 |
| `antique_items` | 文玩藏品档案 |
| `valuation_records` | 遗留估值兼容表；应用层已下线 |
| `patting_logs` | 文玩盘玩/打卡日志 |
| `daily_reviews` | 每日复盘热表 |
| `weekly_reports` | 每周周报 |
| `chat_turns` | 复盘对话、离线便签和每日云端 turn 计数 |
| `review_generation_jobs` | 深夜/前台补偿生成任务冷表 |
| `milestones` | 高光主表 |
| `milestone_relations` | 高光多源关系 |
| `resume_profile` | 简历个人资料 |
| `work_experiences` | 工作经历 |
| `educations` | 教育经历 |
| `skill_items` | 技能项 |
| `project_experiences` | 项目经历 |
| `project_milestone_relations` | 项目经历与高光多对多关系 |
| `vector_embeddings` | 本地向量表，Float32 little-endian BLOB |

架构约束：

1. `daily_reviews.date` 和 `daily_reviews.summary` 是热字段，后续只追加列，不重命名、不改类型。
2. `milestone_relations.source_type/source_id` 是多态关系，必须由 DAO/Repository 在事务中维护完整性。
3. `vector_embeddings` 当前只是底座；没有 embedding 生成、重建任务和 RAG 产品链路前，不应让 UI 暴露“长期记忆已可用”的暗示。
4. `valuation_records` 和 `antique_items.current_valuation` 只作兼容壳；除非单独迁移版本完整验证，否则不物理删除。

## 7. 模块依赖流

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
  -> Review raw context pack 的兴趣/情绪素材来源

AI Assistant
  -> ReviewRepository -> ReviewDao -> daily_reviews / weekly_reports
  -> ChatTurnDao -> chat_turns
  -> ReviewGenerationJobDao -> review_generation_jobs
  -> NightlyStructuredReviewRunner -> AIOutputParser / ReviewGenerationJobStore
  -> MilestoneDao -> milestones / milestone_relations / project_milestone_relations
  -> VectorEmbeddingDao -> vector_embeddings / Dart linear cosine search
  -> AILogScheduler: Android WorkManager 或桌面/Web No-Op
  -> AIService: OfflineReviewGenerator 或 OpenAIService

Resume
  -> ResumeRepository -> ResumeDao
  -> resume_profile / work_experiences / educations / skill_items / project_experiences
  -> future: project_milestone_relations -> milestones
```

## 8. 测试现状

已有较多专项测试覆盖 DAO、迁移、备份、路由和策略服务。仍不合理的是 `test/app_test.dart` 和 `test/widget_test.dart` 还停留在占位断言，不能表达真实应用冒烟能力。

下一阶段测试重心：

1. 前台补偿执行 pending `review_generation_jobs` 的端到端测试。
2. 高光确认/忽略/绑定项目的 DAO 与 UI 测试。
3. PDF 导出服务的结构测试和关键文本断言。
4. 备份导入预检、manifest 和错误报告测试。
5. 替换占位 app/widget 测试为真实启动、路由和 Provider 初始化冒烟测试。
