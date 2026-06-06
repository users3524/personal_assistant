# 软件系统架构设计

## 一、技术栈选型

| 层级 | 技术方案 | 说明 |
|------|----------|------|
| 跨平台框架 | Flutter 3.x + Dart 3.x | 一套代码覆盖 Android / iOS |
| 状态管理 | Riverpod 2.x | 编译安全、可测试、异步数据流优雅 |
| 本地数据库 | drift + sqlite3_flutter_libs | SQLite ORM，编译时类型安全 |
| 路由 | go_router | 声明式路由，支持嵌套导航 |
| 网络请求 | dio | 拦截器、重试、超时管理 |
| AI 接口 | dio + OpenAI 兼容 API | 抽象接口，可切换供应商 |
| 图表 | fl_chart | 折线图、柱状图、饼图 |
| PDF 生成 | pdf + printing | A4 布局渲染 + 系统打印/分享 |
| 本地通知 | flutter_local_notifications | 定时/即时通知 |
| 图片处理 | image_picker + path_provider | 拍照/相册 + 沙盒路径管理 |
| 加密 | encrypt (AES) | API Key 和备份文件加密 |
| 国际化 | flutter_localizations + intl | .arb 文件管理多语言 |

## 二、整体分层架构

```
lib/
├── main.dart                      # 入口
├── app/                           # 全局配置
│   ├── app.dart                   # MaterialApp + 主题 + 路由
│   ├── router/
│   │   ├── app_router.dart        # go_router 路由表
│   │   └── route_names.dart       # 路由名称常量
│   └── theme/
│       ├── app_theme.dart         # 主题定义 + 模式切换
│       ├── app_colors.dart        # 色彩常量
│       └── app_text_styles.dart   # 字体层级
├── core/                          # 基础设施
│   ├── database/
│   │   ├── app_database.dart      # AppDatabase extends $AppDatabase
│   │   ├── app_database.g.dart    # drift 自动生成
│   │   ├── converters/            # TypeConverter
│   │   │   ├── string_list_converter.dart
│   │   │   └── valuation_record_converter.dart
│   │   └── tables/
│   │       └── user_preferences_table.dart
│   ├── ai/
│   │   ├── ai_service.dart        # 抽象接口
│   │   ├── openai_service.dart    # OpenAI 实现
│   │   └── ai_prompts.dart        # 提示词模板
│   ├── network/
│   │   └── api_client.dart        # dio 实例单例
│   ├── utils/
│   │   ├── date_utils.dart
│   │   ├── validators.dart
│   │   └── constants.dart
│   └── widgets/                   # 跨模块通用组件
│       ├── app_scaffold.dart
│       ├── loading_overlay.dart
│       ├── empty_state.dart
│       └── confirm_dialog.dart
└── features/                      # 按业务模块垂直切分
    ├── todo/                      # 待办模块
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── collection/                # 文玩模块
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    ├── ai_assistant/              # AI 复盘模块
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    └── resume/                    # 简历模块
        ├── data/
        ├── domain/
        └── presentation/
```

## 三、Feature 内部三层结构

每个 feature 内部遵循 Clean Architecture 分层：

```
feature/
├── data/                          # 数据层
│   ├── datasources/               # 本地数据库 / 网络 API 调用
│   ├── models/                    # DTO，JSON 序列化/反序列化
│   └── repositories/              # 仓库接口实现
├── domain/                        # 业务层（纯 Dart，零 Flutter 依赖）
│   ├── entities/                  # 纯 Dart 业务实体
│   ├── repositories/              # 仓库抽象接口
│   └── usecases/                  # 单一职责业务用例
└── presentation/                  # 表示层
    ├── providers/                 # Riverpod 状态管理
    ├── pages/                     # 页面
    └── widgets/                   # 本模块专用组件
```

## 四、路由设计（go_router）

```dart
// 路由表结构
/                    → MainShell (StatefulShellRoute, 5 Tab)
├── /todos           → TodoListPage
│   ├── /todos/new   → TodoFormPage
│   └── /todos/:id   → TodoDetailPage
├── /collection      → AntiqueListPage
│   ├── /collection/new → AntiqueFormPage
│   └── /collection/:id → AntiqueDetailPage
├── /review          → ReviewHomePage
│   ├── /review/daily/new   → DailyReviewFormPage
│   ├── /review/daily/:date → DailyReviewDetailPage
│   └── /review/weekly/:id  → WeeklyReportPage
├── /resume          → ResumeHomePage
│   ├── /resume/preview → ResumePreviewPage
│   └── /resume/templates → ResumeTemplatePicker
└── /settings        → SettingsPage
```

## 五、数据库设计规范（drift）

### 5.1 表定义规范

所有表继承 `Table` 类，使用 drift 的列类型系统：

```dart
import 'package:drift/drift.dart';

class UserPreferences extends Table {
  @override
  String get tableName => 'user_preferences';

  IntColumn get id => integer().autoIncrement()();       // 自增主键
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get notificationEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
}
```

### 5.2 TypeConverter 处理复杂类型

SQLite 不支持 `List<String>` 或自定义对象，使用 TypeConverter 序列化为 JSON 字符串：

```dart
// core/database/converters/string_list_converter.dart
import 'package:drift/drift.dart';
import 'dart:convert';

/// 将 List<String> 序列化为 JSON 字符串存入 SQLite
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String column) =>
      (jsonDecode(column) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

// 使用示例
TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
```

### 5.3 数据库入口

```dart
// core/database/app_database.dart
import 'package:drift/drift.dart';
import 'tables/user_preferences_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [UserPreferences])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}
```

## 六、模块间数据流

```
[待办模块: 完成任务 + 耗时/延期数据] ──(自动聚合)──┐
                                                   │
[文玩模块: 盘玩时长 + 打卡频率] ──────────────┐  ▼
                                         ├──► [AI 复盘模块]
[用户手动输入: 今日心得/不足/情绪] ────────────┘     │
                                                     ▼ (一键导入亮点)
                                               [动态简历仓库]
                                                     ▼
                                             [PDF / Markdown 导出]
```

### 数据流说明

1. **待办 → AI**：每日复盘时，AI 模块通过 `completedTodoIds` 关联查询当日完成的待办，获取标题、耗时、延期次数等，作为 Prompt 上下文
2. **文玩 → AI**：AI 模块读取当日 `PattingLogs` 的盘玩总时长，用于评估「解压指数」
3. **AI → 简历**：周报中的 highlights 可一键导入简历模块的 `ProjectExperiences` 表，成为项目经历素材
4. **所有数据 → 备份**：Settings 页导出时遍历所有 drift 表，序列化为结构化 JSON，AES-256-CBC 加密后保存
