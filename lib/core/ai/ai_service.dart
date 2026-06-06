/// AI 服务抽象接口。
///
/// 定义所有与 AI 模型交互的标准接口，支持多种实现：
/// - OpenAIService：对接 OpenAI 兼容 API
/// - 可扩展：Azure OpenAI、本地模型、国产大模型
library;

/// AI 日复盘输出
class DailyReviewAIOutput {
  /// AI 评语（50-100 字）
  final String comment;

  /// AI 改进建议（50-100 字）
  final String suggestion;

  /// 情绪标签：高效 / 平稳 / 焦虑 / 疲惫
  final String sentimentTag;

  DailyReviewAIOutput({
    required this.comment,
    required this.suggestion,
    required this.sentimentTag,
  });
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

  DailyReviewSummary({
    required this.date,
    required this.summary,
    this.highlights,
    this.improvements,
    required this.energyLevel,
    required this.moodLevel,
    required this.completedCount,
    required this.pattingMinutes,
  });
}

/// AI 周报输出
class WeeklyReportAIOutput {
  /// 本周概览（100-150 字）
  final String overview;

  /// 亮点（3-5 条）
  final String highlights;

  /// 待改进（2-3 条）
  final String improvements;

  /// 下周计划（3-5 条）
  final String nextWeekPlan;

  WeeklyReportAIOutput({
    required this.overview,
    required this.highlights,
    required this.improvements,
    required this.nextWeekPlan,
  });
}

abstract class AIService {
  /// 生成日复盘。
  ///
  /// 传入结构化精简文本（非全文），有效控制 Token 消耗。
  Future<DailyReviewAIOutput> generateDailyReview({
    required String summary,
    String? highlights,
    String? improvements,
    required int energyLevel,
    required int moodLevel,
    required List<String> completedTitles,
    required int pattingMinutes,
  });

  /// 生成周报。
  ///
  /// 传入本周日报的结构化精简摘要列表，每条仅包含核心字段。
  Future<WeeklyReportAIOutput> generateWeeklyReport({
    required int weekNumber,
    required int year,
    required List<DailyReviewSummary> weekReviews,
  });

  /// 自由对话。
  Future<String> chat(String message);

  /// 检查服务是否可用（API Key 已配置、网络可达）
  Future<bool> isAvailable();
}
