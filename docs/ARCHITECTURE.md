# 软件系统架构设计

## 一、技术栈选型

| 层级 | 技术方案 | 说明 |
|------|----------|------|
| 跨平台框架 | Flutter 3.x + Dart 3.x | 一套代码覆盖 Android / iOS |
| 状态管理 | Riverpod 2.x | 编译安全、可测试、异步数据流优雅 |
| 本地数据库 | drift + sqlite3_flutter_libs | SQLite ORM，编译时类型安全 |
| 路由 | go_router | 声明式路由，支持嵌套导航 |
| AI 接口 | dio + OpenAI 兼容 API | 抽象接口，可切换供应商 |
| 图表 | fl_chart | 折线图、柱状图、饼图 |
| PDF 生成 | pdf + printing | A4 布局渲染 + 系统打印/分享 |
| 本地通知 | flutter_local_notifications | 定时/即时通知 |
| 图片处理 | image_picker | 拍照/相册 → Base64 存入 SQLite |
| 备份导出 | 纯 JSON + Base64 内联图片 | 换设备/清缓存不丢数据 |
| 国际化 | flutter_localizations + intl | .arb 文件管理多语言 |
| 状态管理 | speech_to_text | AI 复盘语音输入 |

## 二、整体分层架构

```
lib/
├── main.dart                      # 入口
├── app/                           # 全局配置
│   ├── app.dart                   # MaterialApp + 主题 + 路由 + 数据库初始化
│   ├── router/
│   │   ├── app_router.dart        # go_router 路由表（5 Tab StatefulShellRoute）
│   │   └── route_names.dart       # 路由名称常量
│   └── theme/
│       ├── app_theme.dart         # 主题定义 + 模式切换
│       ├── app_colors.dart        # 色彩常量
│       └── app_text_styles.dart   # 字体层级
├── core/                          # 基础设施
│   ├── ai/
│   │   ├── ai_service.dart        # 抽象接口 (AIService)
│   │   ├── openai_service.dart    # OpenAI 兼容实现（Dio）
│   │   ├── ai_prompts.dart        # 提示词模板
│   │   └── ai_provider.dart       # Riverpod Provider (自动加载/持久化配置)
│   └── database/
│       ├── app_database.dart      # AppDatabase + schemaV2 迁移
│       ├── app_database.g.dart    # drift 自动生成（勿手动编辑）
│       ├── app_database_provider.dart  # 异步数据库 FutureProvider
│       ├── backup_service.dart    # JSON 导出/导入（含 Base64 图片内联）
│       ├── user_preferences_dao.dart   # 用户偏好读写
│       ├── converters/
│       │   └── string_list_converter.dart  # List<String> ↔ JSON
│       └── tables/
│           └── user_preferences_table.dart
└── features/                      # 按业务模块垂直切分
    ├── collection/                # 文玩模块
    │   ├── data/datasources/      # antique_dao + 3张表定义
    │   ├── domain/entities/       # AntiqueEntity, PattingLogEntity
    │   ├── domain/repositories/   # 抽象接口
    │   └── presentation/          # 表单/详情/列表/网格卡片/时间线/对比
    ├── todo/                      # 待办模块
    ├── ai_assistant/              # AI 复盘模块（对话式）
    ├── resume/                    # 简历模块
    └── settings/                  # 设置页（主题/AI/备份/通知）
```

## 三、Feature 内部三层结构

每个 feature 内部遵循 Clean Architecture 分层：

```
feature/
├── data/                          # 数据层
│   ├── datasources/               # DAO（本地数据库操作）+ drift 表定义
│   └── repositories/              # 仓库接口实现 + Riverpod Provider
├── domain/                        # 业务层（纯 Dart，零 Flutter 依赖）
│   ├── entities/                  # 纯 Dart 业务实体
│   ├── repositories/              # 仓库抽象接口
│   └── usecases/                  # 单一职责业务用例（部分模块）
└── presentation/                  # 表示层
    ├── providers/                 # Riverpod 状态管理
    ├── pages/                     # 页面
    └── widgets/                   # 本模块专用组件
```

## 四、路由设计

```
/                         → MainShell (StatefulShellRoute, 5 Tab)
Tab 0: /collection        → AntiqueListPage
       /collection/new    → AntiqueFormPage
       /collection/:id    → AntiqueDetailPage
         /collection/:id/edit → AntiqueFormPage(editId)
Tab 1: /todos             → TodoListPage
       /todos/new         → TodoFormPage
       /todos/:id         → TodoDetailPage
         /todos/:id/edit  → TodoFormPage(editId)
Tab 2: /review            → ReviewHomePage
       /review/daily/new  → DailyReviewChatPage
       /review/daily/:date → DailyReviewDetailPage
       /review/weekly/:id → WeeklyReportPage
Tab 3: /resume            → ResumeHomePage
       /resume/preview    → ResumePreviewPage
       /resume/templates  → ResumePreviewPage
Tab 4: /settings          → SettingsPage
```

## 五、数据库设计（drift）

### 表清单（13 张）

| 表名 | 用途 |
|---|---|
| `user_preferences` | 用户设置（主题/AI配置/通知/语言） |
| `todos` | 待办事项 |
| `antique_items` | 藏品主表（含 categoryMetadata JSON） |
| `valuation_records` | 估值记录 |
| `patting_logs` | 盘玩打卡日志 |
| `daily_reviews` | 每日 AI 复盘 |
| `weekly_reports` | 每周周报 |
| `resume_profile` | 简历个人资料 |
| `work_experiences` | 工作经历 |
| `educations` | 教育经历 |
| `skill_items` | 技能项 |
| `project_experiences` | 项目经历 |

### 版本管理

- `schemaVersion = 2`
- v1→v2 迁移：`ALTER TABLE antique_items ADD COLUMN category_metadata TEXT`

### 图片存储方案

- 所有图片以 **Base64 字符串**直接存入 `imagePaths`/`photoPaths` 列表字段
- **导出**：Base64 数据随 JSON 一并导出，换设备不丢
- **导入**：检测 `base64:` 前缀 → 解码写入临时目录 → 恢复为文件路径
- 备份文件为纯 JSON，无加密（用户自行管理文件安全）

## 六、模块间数据流

```
[待办模块: 完成任务数据] ─────────────────────┐
                                             │
[文玩模块: 盘玩打卡 + 照片记录] ──────────┐  ▼
                                       ├──► [AI 复盘模块]
[用户对话输入: 今日心得/不足/情绪] ──────┘     │
                                               ▼
                                         [每日日报 + 每周周报]
                                               │
                                    分析改进点置顶
                                    周末自动汇总
```
