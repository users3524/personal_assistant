[English](./README_EN.md) | [中文](./README.md)

# 个人全能助手

待办、文玩记录、AI 复盘、动态简历集成在一个 Flutter 本地优先应用里。当前代码以 Android 为主要运行目标，同时保留 Windows / Web 工程。

> 本文按 2026-06-20 的代码现状整理。未实现的深夜日报、RAG、人生罗盘、STAR 简历生成、PDF 导出等，只记录在 `docs/ROADMAP.md` 和 `docs/TODO.md`。

## 当前原则

| 原则 | 当前实现 |
| --- | --- |
| 本地优先 | 业务数据存储在本地 SQLite。 |
| 隐私优先 | 无广告 SDK、无统计 SDK；AI 请求只发往用户在设置页配置的地址。 |
| 模块化 | 文玩、待办、复盘、简历、设置按 feature 目录拆分。 |
| 文档按代码说话 | 当前规格只描述已实现代码，不把规划写成现状。 |

## 全局演进取舍

当前文档把“已实现现状”和“后续智能化规划”分开维护。后续实现顺序统一按以下阶段推进：

1. 先修现有数据债：备份导入导出、API Key 安全存储、文玩估值应用层下线、图片路径统一。
2. 再修现有功能链路：待办树查询、复盘真实文玩分钟、输入/STT 限制、周报日期范围查询、简历编辑缺口。
3. 然后落地 AI 成本闸门：`PromptBuilder`、`chat_turns`、15 轮熔断、离线便签。
4. 再做深夜引擎：先前台 Catch-Up Guard 补偿闭环，再接 Android WorkManager。
5. 最后进入长期智能化：高光池、向量记忆、人生罗盘、RAG、STAR 简历和 PDF 导出。

## 快速开始

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Windows 用户可运行 `build_and_run.bat` 进行本地构建和安装。当前 `pubspec.yaml` 版本为 `1.0.2+3`，Dart SDK 约束为 `^3.10.0`。

## 当前功能模块

### 文玩/盘串

入口：`/collection`

当前已实现：

- 藏品建档：名称、分类、子类型、入手日期、入手价格、来源、品相、图片、备注、分类专属字段。
- 文玩分类管理：默认核桃、手串、把件；支持子类型和专属字段管理。
- 盘玩打卡：照片、时长、方式、备注、时间线展示。
- 列表与月历：网格视图、月历视图、最新打卡照片、每日翻牌、趣味榜单。
- 照片能力：全屏查看、分享、保存、打卡照片对比。
- 估值下线：估值图表、估值 Provider、估值实体/仓库接口、财富/潜力榜和 `fl_chart` 依赖已移除。

兼容口径：`valuation_records` 表和 `antique_items.current_valuation` 字段仍保留在 schema v6 中，作为旧数据库/旧备份兼容壳；新导出的 `valuation_records` 为空，旧备份导入时会把估值历史按藏品归档到 `antique_items.notes`。

### 待办

入口：`/todos`

当前已实现：

- 待办创建、编辑、详情、开始、完成、取消、重新打开、星标、软删除、归档。
- 父任务和子任务：`todos.parent_id` 自关联；详情页可添加子任务。
- 清单表：`todo_lists` 已有表和 DAO，UI 使用仍有限。
- 周/月视图：周视图展示今日任务与统计卡；月视图展示日报标记和历史入口。
- 统计：今日完成数、今日总数、本周完成率、拖延率；统计口径排除子任务。
- 分类：默认“生活/工作”，分类列表保存在 `user_preferences.todo_categories`。

当前未实现：AI 教练式待办追问、人生罗盘绑定、15 轮熔断、输入 500 字硬限制。

### AI 复盘

入口：

- `/review/daily/new`
- `/review/daily/edit/:date`
- `/review/daily/:date`
- `/review/weekly/:id`

当前已实现：

- 对话式日报：按总结、收获、不足、情绪/能量、AI 建议逐步收集。
- 日报详情：查看、编辑、删除。
- 周报：按年和周数生成/查看。
- AI 服务：离线模板生成器和 OpenAI 兼容接口。
- 语音输入：使用 `speech_to_text` 转文本。

当前未实现：深夜 2:00-5:00 后台引擎、充电/Wi-Fi 条件、结构化 JSON 输出、解析失败重试、RAG/向量库、自动高光里程碑。

### 动态简历

入口：`/resume`

当前已实现：

- 个人资料、工作经历、教育经历、技能、项目经历。
- 可见性开关和拖拽排序。
- 三套 Flutter 预览模板：简洁经典、现代卡片、技术极简。
- 技术栈、项目标签、关键交付在模板层可展示。
- 导出分享：通过 `RepaintBoundary` 截取当前预览为 PNG，再使用 `share_plus` 分享。

当前未实现：PDF 导出、Markdown 导出、STAR AI 润色、里程碑素材池、从日报/周报导入高光。

### 设置

入口：`/settings`

当前已实现：

- 主题、AI Provider/baseUrl/model/apiKey、通知开关。
- 每日复盘、每周周报通知配置。
- 文玩分类管理、每日翻牌配置、文玩网格列数。
- JSON 备份导出/导入。
- Flutter 开源许可页。

## 技术栈

| 层级 | 当前依赖 | 用途 |
| --- | --- | --- |
| UI | Flutter | 跨平台界面。 |
| 状态管理 | `flutter_riverpod` | Provider 状态流。 |
| 路由 | `go_router` | 3 个底部 Tab 和全屏路由。 |
| 数据库 | `drift` + `sqlite3_flutter_libs` | 本地 SQLite。 |
| 网络 | `dio` | OpenAI 兼容 API。 |
| 通知 | `flutter_local_notifications` + `timezone` | 本地提醒。 |
| 图片 | `image_picker` + `gal` | 拍照/选图和保存到相册。 |
| 分享 | `share_plus` | 简历图片、文玩图片分享。 |
| 语音 | `speech_to_text` | 复盘语音输入。 |
| 文件 | `file_picker` | JSON 备份导入导出。 |

当前没有 `pdf` / `printing` 依赖。

## 数据库

当前 `schemaVersion = 6`，注册 14 张表：

| 表 | 用途 |
| --- | --- |
| `user_preferences` | 主题、语言、通知、AI 配置、复盘提醒、简历模板 ID、待办分类 JSON。 |
| `collection_categories` | 文玩分类、子类型、专属字段、排序。 |
| `todo_lists` | 待办清单。 |
| `todos` | 待办任务、父子关系、状态、标签、软删除、重复策略。 |
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

## 当前路由

底部导航当前只有 3 个 Tab：

```text
/collection    盘串
/todos         待办
/resume        简历
```

全屏路由：

```text
/settings
/review/daily/new
/review/daily/edit/:date
/review/daily/:date
/review/weekly/:id
```

`RouteNames` 中保留了 `/review`、`/resume/preview`、`/resume/templates` 常量，但当前路由表没有注册这些独立页面。后续计划将 `ReviewHomePage` 注册为独立 `/review` 历史入口，但不新增底部 Tab。

## 项目结构

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

Feature 内部基本按 `data/domain/presentation` 分层。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [总览规格](docs/SPEC_PERSONAL_AI_ASSISTANT.md) | 当前功能、当前数据库、AI 边界、估值口径。 |
| [架构现状](docs/ARCHITECTURE.md) | 项目结构、路由、依赖、数据库、平台现状。 |
| [待办规格](docs/SPEC_TODO.md) | 待办表、DAO、Repository、页面、统计口径。 |
| [文玩规格](docs/SPEC_COLLECTION.md) | 文玩表、页面、打卡、分类、估值移除口径。 |
| [复盘规格](docs/SPEC_REVIEW.md) | 日报/周报、AI 服务、对话流程、未实现边界。 |
| [简历规格](docs/SPEC_RESUME.md) | 简历表、模板、编辑、导出边界。 |
| [安全与备份](docs/SECURITY.md) | 本地数据、AI 请求、JSON 备份风险。 |
| [路线图](docs/ROADMAP.md) | 后续代码债和功能规划。 |
| [TODO](docs/TODO.md) | 待实现清单。 |
| [实施计划](docs/PLAN.md) | 当前建议实现顺序和协作约定。 |

## 隐私与安全

- 数据库和备份 JSON 当前为本地明文；AI Key 已迁移到平台安全存储，备份不再导出密钥。
- AI 请求只会发往用户配置的 Provider/baseUrl。
- JSON 备份可能包含个人资料、藏品入手价格、图片 Base64；不再包含 AI API Key。
- 备份导入当前是覆盖恢复，不是合并恢复。

更多细节见 [docs/SECURITY.md](docs/SECURITY.md)。

## License

本项目当前未选择正式开源许可证，保留所有权利。
