# AI 复盘模块 — 详细规格说明

## 一、数据模型

### 1.1 日报表

```dart
// features/ai_assistant/data/datasources/daily_reviews_table.dart
import 'package:drift/drift.dart';
import '../../../../core/database/converters/string_list_converter.dart';

class DailyReviews extends Table {
  @override
  String get tableName => 'daily_reviews';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().uniqueKey()();       // 每天一条，按日期唯一
  TextColumn get summary => text()();                         // 今日总结（用户填写）
  TextColumn get highlights => text().nullable()();           // 今日收获（用户填写）
  TextColumn get improvements => text().nullable()();         // 今日不足（用户填写）
  IntColumn get energyLevel => integer()();                   // 能量水平 1-5
  IntColumn get moodLevel => integer()();                     // 情绪水平 1-5

  // 关联数据
  TextColumn get completedTodoIds => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();                   // 今日完成的待办 ID 列表
  IntColumn get pattingMinutes => integer()
      .withDefault(const Constant(0))();                       // 今日盘玩总时长

  // AI 输出
  TextColumn get aiComment => text().nullable()();            // AI 评语
  TextColumn get aiSuggestion => text().nullable()();         // AI 改进建议
  BoolColumn get isAiGenerated => boolean().withDefault(const Constant(false))();
  BoolColumn get isManuallyEdited => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();
}
```

### 1.2 周报表

```dart
class WeeklyReports extends Table {
  @override
  String get tableName => 'weekly_reports';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get weekNumber => integer()();                     // 年内第几周 (1-53)
  IntColumn get year => integer()();

  // AI 生成的结构化内容
  TextColumn get overview => text()();                          // 本周概览
  TextColumn get highlights => text()();                        // 本周亮点
  TextColumn get improvements => text()();                      // 待改进
  TextColumn get nextWeekPlan => text()();                      // 下周计划

  BoolColumn get isAiGenerated => boolean().withDefault(const Constant(false))();
  BoolColumn get isManuallyEdited => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime())();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();

  // 唯一约束：每年每周一条
  @override
  Set<Column> get uniqueKey => {weekNumber, year};
}
```

## 二、AI 服务设计

### 2.1 抽象接口

```dart
// core/ai/ai_service.dart

/// AI 日复盘输出
class DailyReviewAIOutput {
  final String comment;       // 评语（50-100 字）
  final String suggestion;    // 改进建议（50-100 字）
  final String sentimentTag;  // 情绪标签：高效/平稳/焦虑/疲惫
}

/// 日报精简摘要（传给 AI 的结构化格式）
class DailyReviewSummary {
  final String date;
  final String summary;
  final String? highlights;
  final String? improvements;
  final int energyLevel;
  final int moodLevel;
  final int completedCount;
  final int pattingMinutes;
}

/// AI 周报输出
class WeeklyReportAIOutput {
  final String overview;      // 周概览（100-150 字）
  final String highlights;    // 亮点（3-5 条）
  final String improvements;  // 待改进（2-3 条）
  final String nextWeekPlan;  // 下周计划（3-5 条）
}

abstract class AIService {
  /// 生成日复盘 — ✅ 传入结构化精简文本，非全文，控制 Token
  Future<DailyReviewAIOutput> generateDailyReview({
    required String summary,
    String? highlights,
    String? improvements,
    required int energyLevel,
    required int moodLevel,
    required List<String> completedTitles,   // 待办标题列表（仅标题，非全文）
    required int pattingMinutes,
  });

  /// 生成周报 — ✅ 传入本周日报的结构化精简摘要
  Future<WeeklyReportAIOutput> generateWeeklyReport({
    required int weekNumber,
    required int year,
    required List<DailyReviewSummary> weekReviews,  // 精简摘要列表
  });

  /// 自由对话
  Future<String> chat(String message);
}
```

### 2.2 Token 控制策略

```
日报 Prompt 预估 Token 消耗：
  - 系统消息：~200 tokens
  - 用户输入（摘要+收获+不足）：~200 tokens
  - 待办标题列表（平均 5 条 × 10 字）：~50 tokens
  - 盘玩时长：~10 tokens
  总计：~500 tokens / 次

周报 Prompt 预估 Token 消耗：
  - 系统消息：~300 tokens
  - 7 天 × 日报精简摘要（每条 ~100 tokens）：~700 tokens
  总计：~1000 tokens / 次
```

> **注意**：传入 AI 的日报数据**不是原始日报全文**，而是 `DailyReviewSummary` 结构化精简文本，每条仅包含 `summary`、`highlights`、`improvements` 三个核心字段，去除不必要的描述，大幅降低 Token 消耗。

### 2.3 提示词模板

```dart
// core/ai/ai_prompts.dart

class AIPrompts {
  static String dailyReviewSystemPrompt() => '''
你是一个温暖、专业的个人成长助手。用户的每日复盘数据如下：
- 今日总结：{summary}
- 今日收获：{highlights}
- 今日不足：{improvements}
- 能量水平：{energyLevel}/5
- 情绪水平：{moodLevel}/5
- 完成任务：{completedTitles}
- 盘玩放松：{pattingMinutes}分钟

请生成：
1. 评语（50-100字，温暖鼓励的语气）
2. 改进建议（50-100字，具体可操作）
3. 情绪标签（高效/平稳/焦虑/疲惫）

注意：不要说教，像朋友一样给出反馈。
''';

  static String weeklyReportSystemPrompt() => '''
你是一个专业的职场复盘助手。以下是用户本周的每日复盘摘要：

{weekReviews}

请生成一份结构化周报：
1. **本周概览**：100-150字，总结本周整体表现
2. **本周亮点**：3-5条，具体可量化
3. **待改进**：2-3条，建设性建议
4. **下周计划**：3-5条，SMART原则

格式要求：使用 Markdown 粗体标记标题，每条内容用短句。
''';
}
```

## 三、日报流程

### 3.1 触发方式

| 方式 | 说明 |
|------|------|
| 定时通知 | 默认 21:00 本地通知提醒 |
| 手动进入 | 从 Tab 进入复盘页面 |
| 完成后自动 | 当日完成所有待办后自动弹出提示 |

### 3.2 填写步骤

1. **数据准备**：页面自动加载当日已完成的 Todo 列表 + 盘玩总时长
2. **用户填写**：
   - 今日总结（必填，50-200 字）
   - 今日收获（可选）
   - 今日不足（可选）
   - 能量水平（1-5 星）
   - 情绪水平（1-5 星 + emoji）
3. **AI 复盘**：点击「AI 复盘」按钮 → 调用 AI → 展示评语和建议
4. **人工编辑**：用户可修改 AI 内容或重新生成
5. **保存**：标记 `isAiGenerated` 和 `isManuallyEdited`

## 四、周报流程

### 4.1 触发方式

| 方式 | 说明 |
|------|------|
| 定时通知 | 每周日 20:00 提醒 |
| 手动生成 | 从周报列表页进入 |

### 4.2 生成步骤

1. **数据聚合**：读取本周 7 天的日报记录
2. **构建精简摘要**：每条日报提取为 `DailyReviewSummary` 结构
3. **调用 AI**：传入精简摘要列表给 `generateWeeklyReport()`
4. **展示与编辑**：用户查看 AI 生成的结构化周报，可自由编辑
5. **保存**：标记 `isAiGenerated` 和 `isManuallyEdited`

## 五、数据看板

| 图表 | 类型 | 数据源 |
|------|------|--------|
| 情绪曲线 | fl_chart 折线图 | 日报的 moodLevel |
| 能量曲线 | fl_chart 折线图 | 日报的 energyLevel |
| 情绪能量叠加图 | 双轴折线图 | moodLevel + energyLevel |
| 日报完成率 | 日历热力图 | 是否有日报记录 |
| 周报趋势 | 柱状图 | 每周完成率对比 |

## 六、AI 亮点导入简历

在周报详情页，每个 `highlights` 条目旁有一个「导入简历」按钮：

1. 点击后弹出确认对话框，选择目标项目经历
2. 将该高亮内容克隆为一个新的 `ProjectExperience` 条目
3. 自动填入 `name`（周报第 X 周亮点）和 `description`
4. 用户可在简历编辑页进一步修改

## 七、DAO 接口

```dart
class ReviewDao {
  // 日报
  Future<DailyReview> insertDaily(DailyReviewsCompanion entry);
  Future<DailyReview> updateDaily(int id, DailyReviewsCompanion entry);
  Future<DailyReview?> getDailyByDate(DateTime date);
  Future<List<DailyReview>> getDailyByMonth(int year, int month);
  Future<List<DailyReview>> getDailyByWeek(int year, int weekNumber);

  // 周报
  Future<WeeklyReport> insertWeekly(WeeklyReportsCompanion entry);
  Future<WeeklyReport> updateWeekly(int id, WeeklyReportsCompanion entry);
  Future<WeeklyReport?> getWeekly(int year, int weekNumber);
  Future<List<WeeklyReport>> getWeeklyByYear(int year);

  // 统计
  Future<double> averageMoodInRange(DateTime start, DateTime end);
  Future<double> averageEnergyInRange(DateTime start, DateTime end);
  Future<int> countDailyInRange(DateTime start, DateTime end);
}
```
