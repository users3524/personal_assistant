/// AI 提示词模板管理。
///
/// 所有发送给 AI 模型的系统消息 Prompt 集中管理在此文件中，
/// 便于统一优化和版本管理。
class AIPrompts {
  AIPrompts._();

  /// 日复盘系统提示词
  static String dailyReviewSystemPrompt({
    required String summary,
    String? highlights,
    String? improvements,
    required int energyLevel,
    required int moodLevel,
    required List<String> completedTitles,
    required int pattingMinutes,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('你是一个温暖、专业的个人成长助手。用户的每日复盘数据如下：');
    buffer.writeln('- 今日总结：$summary');
    buffer.writeln('- 今日收获：${highlights ?? "未填写"}');
    buffer.writeln('- 今日不足：${improvements ?? "未填写"}');
    buffer.writeln('- 能量水平：$energyLevel/5');
    buffer.writeln('- 情绪水平：$moodLevel/5');
    buffer.writeln('- 完成任务：${completedTitles.isEmpty ? "无" : completedTitles.join("、")}');
    buffer.writeln('- 盘玩放松：$pattingMinutes分钟');
    buffer.writeln('');
    buffer.writeln('请生成以下内容（用纯文本，不要使用 Markdown）：');
    buffer.writeln('1. 评语（50-100字，温暖鼓励的语气）');
    buffer.writeln('2. 改进建议（50-100字，具体可操作的建议）');
    buffer.writeln('3. 情绪标签（从以下选一个：高效/平稳/焦虑/疲惫）');
    buffer.writeln('');
    buffer.writeln('注意：不要说教，像朋友一样给出反馈。用冒号分隔三部分。');
    return buffer.toString();
  }

  /// 周报系统提示词
  static String weeklyReportSystemPrompt({
    required String weekReviewsText,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('你是一个专业的职场复盘助手。以下是用户本周的每日复盘摘要：');
    buffer.writeln('');
    buffer.writeln(weekReviewsText);
    buffer.writeln('');
    buffer.writeln('请生成一份结构化周报，格式如下（用纯文本，每部分用空行分隔）：');
    buffer.writeln('');
    buffer.writeln('【本周概览】');
    buffer.writeln('100-150字，总结本周整体表现');
    buffer.writeln('');
    buffer.writeln('【本周亮点】');
    buffer.writeln('3-5条，具体可量化，每条用"• "开头');
    buffer.writeln('');
    buffer.writeln('【待改进】');
    buffer.writeln('2-3条，建设性建议，每条用"• "开头');
    buffer.writeln('');
    buffer.writeln('【下周计划】');
    buffer.writeln('3-5条，符合SMART原则，每条用"• "开头');
    return buffer.toString();
  }
}
