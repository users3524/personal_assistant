/// 离线复盘生成器 — 基于模板引擎，不依赖任何 AI 模型或网络。
///
/// 用预设的模板短语 + 用户的实际数据（评分、完成事项等）组合生成
/// 日报评语/建议/标签 和 周报概览/亮点/改进/计划。
library;
import 'ai_service.dart';

class OfflineReviewGenerator implements AIService {
  @override
  Future<bool> isAvailable() async => true;

  // ===== 聊天回复（日报对话流程中的 bot 回复） =====

  @override
  Future<String> chat(String message) async {
    // 根据关键词给出模板回复
    final msg = message.trim().toLowerCase();
    if (msg.contains('好') || msg.contains('嗯') || msg.contains('ok') || msg.contains('可以')) {
      return _pick([
        '好的，继续聊聊今天的感受吧～',
        '嗯嗯，我听着呢，然后呢？',
        '好的呢，还有想分享的吗？',
      ]);
    }
    if (msg.contains('没有') || msg.contains('没什么')) {
      return _pick([
        '没关系，平平淡淡也是生活～那我们来打分吧！',
        '好的，那咱们进入评分环节？',
        '理解，那咱们看看今天的整体评分怎么样？',
      ]);
    }
    if (msg.contains('谢谢') || msg.contains('感谢')) {
      return _pick([
        '不客气！每天进步一点点就好 😊',
        '加油！明天会更好～',
        '棒棒哒，继续保持！',
      ]);
    }
    if (msg.contains('累') || msg.contains('烦') || msg.contains('压力')) {
      return _pick([
        '辛苦了！记得给自己一点放松的时间，盘盘串放松一下 🎯',
        '压力大是很正常的，你已经做得很好了！',
        '理解，生活不易，但每天的小进步都值得被看见 💪',
      ]);
    }
    return _pick([
      '收到！还有什么想聊的吗？',
      '明白了，继续说说看～',
      '好嘞，还有呢？',
    ]);
  }

  // ===== 日报生成 =====

  @override
  Future<DailyReviewAIOutput> generateDailyReview({
    required String summary,
    String? highlights,
    String? improvements,
    required int energyLevel,
    required int moodLevel,
    required List<String> completedTitles,
    required int pattingMinutes,
  }) async {
    final comment = _generateComment(energyLevel, moodLevel, completedTitles.length, summary);
    final suggestion = _generateSuggestion(energyLevel, moodLevel, improvements, completedTitles.length);
    final sentimentTag = _generateTag(energyLevel, moodLevel);

    return DailyReviewAIOutput(
      comment: comment,
      suggestion: suggestion,
      sentimentTag: sentimentTag,
    );
  }

  String _generateComment(int energy, int mood, int taskCount, String summary) {
    final avg = (energy + mood) / 2;
    final taskNote = taskCount >= 3
        ? _pick(['完成了 $taskCount 项任务，效率很高！', '今天搞定了 $taskCount 件事，不错哦～'])
        : taskCount > 0
            ? _pick(['完成了 $taskCount 项任务，有在推进～', '有 $taskCount 项完成，每天进步一点点'])
            : _pick(['今天没有完成待办事项，休息也是生活的一部分', '虽然没有待办完成，但复盘本身就是一种自律']);

    if (avg >= 4.5) {
      return _pick([
        '状态满分！$taskNote 继续保持这份热情，你是最棒的！🔥',
        '今天能量和情绪都很在线！$taskNote 完美的一天！✨',
        '太棒了，双高分！$taskNote 每天都像今天这样就很完美～',
      ]);
    } else if (avg >= 3.5) {
      return _pick([
        '状态不错！$taskNote 平稳中带着小确幸，这就是理想的生活节奏 🌤️',
        '今天整体感觉挺好～$taskNote 继续保持这种节奏！',
        '不错的状态！$taskNote 生活中最重要的就是保持这种平衡感 😊',
      ]);
    } else if (avg >= 2.5) {
      return _pick([
        '今天状态一般，$taskNote 给自己一个大大的拥抱，明天会更好 🫂',
        '普通的一天也是生活的一部分，$taskNote 适当放松一下，盘串听听音乐 🎵',
        '不算特别出色但也不差，$taskNote 接受每一天的自己，包括不完美的日子 💪',
      ]);
    } else {
      return _pick([
        '今天可能有点累，$taskNote 别忘了好好休息，明天满血复活 🌙',
        '状态不太好也没关系，$taskNote 累了就歇歇，身体最重要 🫂',
        '今天辛苦了！$taskNote 允许自己偶尔的低能量，充电后再出发 ⚡',
      ]);
    }
  }

  String _generateSuggestion(int energy, int mood, String? improvements, int taskCount) {
    if (energy <= 2) {
      return _pick([
        '建议今晚早点休息，保证 7-8 小时睡眠，明天状态会好很多 😴',
        '能量偏低时可以试试 5 分钟冥想或者出去散散步 🌿',
        '低能量日不用强求效率，把最重要的 1-2 件事做好就够了 🎯',
      ]);
    }
    if (mood <= 2) {
      return _pick([
        '情绪低落时可以盘盘串，研究表明重复性手部动作有助于缓解焦虑 🎯',
        '试试记录三件今天值得开心的小事，培养积极心态 ✍️',
        '如果持续情绪不佳，和信任的朋友聊聊天会好很多 💬',
      ]);
    }
    if (taskCount == 0) {
      return _pick([
        '明天可以试试从最简单的一件待办开始，先完成再完美 🚀',
        '建议每天设定 1-3 个关键任务，优先完成最重要的那个 🎯',
        '试着把大任务拆成小步骤，每完成一步就奖励自己一下 🍵',
      ]);
    }
    if (improvements != null && improvements.isNotEmpty && !improvements.contains('没有')) {
      return _pick([
        '针对你提到的不足，可以试着制定一个小的改进计划，每天进步 1% 📈',
        '有反思就有成长，明天可以在这些方面多留意一下 💪',
        '发现问题就是解决问题的第一步，给自己点个赞！👍',
      ]);
    }
    return _pick([
      '保持今天的节奏，明天可以挑战多完成一件待办事项 🎯',
      '每天花 10 分钟做复盘，长期下来会有惊人的积累 📊',
      '尝试在每天的固定时间做复盘，养成习惯后会很轻松 ⏰',
    ]);
  }

  String _generateTag(int energy, int mood) {
    final avg = (energy + mood) / 2;
    if (avg >= 4.0 && energy >= 4 && mood >= 4) return '高效';
    if (avg >= 3.0) return '平稳';
    if (mood <= 2) return '焦虑';
    return '疲惫';
  }

  // ===== 周报生成 =====

  @override
  Future<WeeklyReportAIOutput> generateWeeklyReport({
    required int weekNumber,
    required int year,
    required List<DailyReviewSummary> weekReviews,
  }) async {
    final overview = _generateWeekOverview(weekReviews);
    final highlights = _generateWeekHighlights(weekReviews);
    final improvements = _generateWeekImprovements(weekReviews);
    final nextWeekPlan = _generateWeekPlan(weekReviews);

    return WeeklyReportAIOutput(
      overview: overview,
      highlights: highlights,
      improvements: improvements,
      nextWeekPlan: nextWeekPlan,
    );
  }

  String _generateWeekOverview(List<DailyReviewSummary> reviews) {
    if (reviews.isEmpty) {
      return '本周没有复盘记录。建议每天花几分钟做复盘，积累下来会看到自己的成长轨迹。';
    }

    final daysCount = reviews.length;
    final avgEnergy = reviews.map((r) => r.energyLevel).reduce((a, b) => a + b) / daysCount;
    final avgMood = reviews.map((r) => r.moodLevel).reduce((a, b) => a + b) / daysCount;
    final totalTasks = reviews.fold<int>(0, (sum, r) => sum + r.completedCount);
    final totalPatting = reviews.fold<int>(0, (sum, r) => sum + r.pattingMinutes);
    final hasHighlights = reviews.any((r) => r.highlights != null && r.highlights!.isNotEmpty && r.highlights != '没有');

    final avgDesc = (avgEnergy + avgMood) / 2 >= 3.5
        ? _pick(['整体状态不错', '状态良好', '度过了充实的一周'])
        : (avgEnergy + avgMood) / 2 >= 2.5
            ? _pick(['状态平稳', '有起有伏的一周', '稳中求进的一周'])
            : _pick(['有些疲惫的一周', '需要调整的一周', '压力较大的一周']);

    final taskDesc = totalTasks > 10
        ? _pick(['完成了 $totalTasks 项任务，执行力很强', '高效完成了 $totalTasks 项待办'])
        : totalTasks > 5
            ? _pick(['完成了 $totalTasks 项任务，有在持续推进', '稳步推进了 $totalTasks 项事务'])
            : _pick(['完成了 $totalTasks 项任务', '完成了少量任务']);

    final pattingDesc = totalPatting > 0
        ? _pick(['盘玩放松 $totalPatting 分钟，劳逸结合做得不错', '有 $totalPatting 分钟的盘玩时光'])
        : '';

    return '本周共复盘 $daysCount 天，$avgDesc。$taskDesc。$pattingDesc'
        '${hasHighlights ? '每天都有收获和反思，值得肯定。' : '建议下周多记录一些亮点和收获。'}'
        '平均能量 $avgEnergy/5，平均情绪 $avgMood/5。';
  }

  String _generateWeekHighlights(List<DailyReviewSummary> reviews) {
    final items = <String>[];
    final highlights =
        reviews.where((r) => r.highlights != null && r.highlights!.isNotEmpty && r.highlights != '没有').toList();

    for (final r in highlights.take(3)) {
      items.add('• ${r.date}: ${r.highlights!.length > 30 ? '${r.highlights!.substring(0, 30)}…' : r.highlights}');
    }

    if (items.isEmpty) {
      items.addAll([
        '• 坚持每天做复盘，培养了自我反思的习惯',
        '• 对自身的状态有了更清晰的认知',
        '• ${_pick(["生活中总有值得被记录的美好", "每一个当下都是成长的契机"])}',
      ]);
    }

    final highMood = reviews.where((r) => r.moodLevel >= 4).toList();
    if (highMood.isNotEmpty) {
      items.add('• 有 ${highMood.length} 天情绪指数达到 4 分以上，心态积极');
    }

    final highEnergy = reviews.where((r) => r.energyLevel >= 4).toList();
    if (highEnergy.isNotEmpty) {
      items.add('• 有 ${highEnergy.length} 天能量充沛，状态在线');
    }

    return items.take(5).join('\n');
  }

  String _generateWeekImprovements(List<DailyReviewSummary> reviews) {
    final items = <String>[];
    final improvements =
        reviews.where((r) => r.improvements != null && r.improvements!.isNotEmpty && r.improvements != '没有').toList();

    for (final r in improvements.take(2)) {
      items.add('• ${r.date}: ${r.improvements!.length > 30 ? '${r.improvements!.substring(0, 30)}…' : r.improvements}');
    }

    final lowEnergy = reviews.where((r) => r.energyLevel <= 2).length;
    if (lowEnergy > 2) {
      items.add('• 本周有 $lowEnergy 天能量偏低，建议关注作息规律');
    }

    final lowMood = reviews.where((r) => r.moodLevel <= 2).length;
    if (lowMood > 2) {
      items.add('• 有 $lowMood 天情绪偏低，可以尝试更多放松活动');
    }

    final noTasks = reviews.where((r) => r.completedCount == 0).length;
    if (noTasks > 3) {
      items.add('• 有 $noTasks 天未完成待办，建议每天设定最小可行目标');
    }

    if (items.isEmpty) {
      items.addAll([
        '• 可以尝试增加复盘的天数，覆盖更全面',
        '• 设定更具挑战性的周目标',
      ]);
    }

    return items.take(3).join('\n');
  }

  String _generateWeekPlan(List<DailyReviewSummary> reviews) {
    final items = <String>[
      '• 坚持每日复盘，记录每天的感受和收获',
      '• ${_pick(["完成下周最重要的 3 个目标", "为下个月设定一个明确的方向"])}',
    ];

    final avgEnergy = reviews.isEmpty
        ? 3.0
        : reviews.map((r) => r.energyLevel).reduce((a, b) => a + b) / reviews.length;
    if (avgEnergy < 3.0) {
      items.add('• 调整作息时间，保证每天 7 小时以上睡眠');
    }

    items.add('• ${_pick(["每周盘玩放松 3-4 次，保持身心平衡", "适当增加户外活动时间"])}');

    final lowMood = reviews.where((r) => r.moodLevel <= 2).length;
    if (lowMood > reviews.length / 3) {
      items.add('• 尝试新的放松方式，如冥想、运动或与朋友聚会');
    }

    items.add('• ${_pick(["给自己定一个小奖励，完成目标后兑现", "整理下周的待办清单，做到心中有数"])}');

    return items.take(5).join('\n');
  }

  // ===== 工具方法 =====

  /// 从列表中随机选一个
  String _pick(List<String> options) {
    return options[DateTime.now().microsecondsSinceEpoch % options.length];
  }
}
