/// 离线复盘生成器 — 基于模板引擎，不依赖任何 AI 模型或网络。
///
/// 根据用户实际填写的总结/收获/不足内容生成对应的模板回复，
/// 而非仅仅根据情绪/能量评分。
library;

import 'ai_service.dart';

class OfflineReviewGenerator implements AIService {
  @override
  Future<bool> isAvailable() async => true;

  // ===== 聊天回复（日报对话流程中的 bot 回复） =====

  @override
  Future<String> chat(String message) async {
    final msg = message.trim();
    if (msg.isEmpty) return '可以聊聊今天的感受哦～';

    // 提取对话上下文中的关键词，给出人性化回应
    if (_containsAny(msg, ['好', '嗯', 'ok', '可以', '是的', '对'])) {
      return _pick([
        '好的，继续聊聊今天的感受吧～',
        '嗯嗯，我听着呢，然后呢？',
        '好的呢，还有想分享的吗？',
        '明白了，还有别的想说的吗？',
      ]);
    }
    if (_containsAny(msg, ['没有', '没什么', '没啥'])) {
      return _pick([
        '没关系，平平淡淡也是生活～那我们来打分吧！',
        '好的，那咱们进入评分环节？',
        '理解，那咱们看看今天的整体评分怎么样？',
      ]);
    }
    if (_containsAny(msg, ['谢谢', '感谢', '辛苦了'])) {
      return _pick([
        '不客气！每天进步一点点就好 😊',
        '加油！明天会更好～',
        '棒棒哒，继续保持！',
      ]);
    }
    if (_containsAny(msg, ['累', '烦', '压力', '忙', '疲惫', '困'])) {
      return _pick([
        '辛苦了！记得给自己一点放松的时间，盘盘串放松一下 🎯',
        '压力大是很正常的，你已经做得很好了！',
        '理解你，生活不易，但每天的小进步都值得被看见 💪',
        '累了就歇歇，身体和心情最重要～',
      ]);
    }
    if (_containsAny(msg, ['开心', '高兴', '顺利', '成功', '完成', '棒', '不错'])) {
      return _pick([
        '太棒了！今天收获满满呀 🎉',
        '真好，听到这个我也很开心！继续保持～',
        '厉害厉害，今天状态很在线嘛！',
      ]);
    }
    if (_containsAny(msg, ['生气', '难过', '伤心', '郁闷', '焦虑', '烦躁'])) {
      return _pick([
        '抱抱你，情绪不好也是正常的，我陪你聊聊？🤗',
        '不开心的事说出来会好受一些，我在听～',
        '情绪低谷总会过去的，今天辛苦了 🫂',
      ]);
    }
    if (_containsAny(msg, ['盘串', '盘玩', '核桃', '手串'])) {
      return _pick([
        '盘串解压效果一流！今天盘了多久呀？🎯',
        '文玩人的快乐就是这么简单～',
        '盘串的时候最放松了，感觉怎么样？',
      ]);
    }
    if (_containsAny(msg, ['复盘', '保存', '确认'])) {
      return _pick([
        '好的，准备复盘保存啦～',
        '确认保存本次复盘？',
      ]);
    }
    // 默认回复
    return _pick([
      '收到！继续说说看～',
      '明白了，还有吗？',
      '好嘞，我记下了，接着说～',
    ]);
  }

  bool _containsAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
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
    final comment = _generateComment(summary, highlights, improvements,
        energyLevel, moodLevel, completedTitles.length);
    final suggestion = _generateSuggestion(
        energyLevel, moodLevel, improvements, completedTitles.length, summary);
    final sentimentTag = _generateTag(energyLevel, moodLevel);

    return DailyReviewAIOutput(
      comment: comment,
      suggestion: suggestion,
      sentimentTag: sentimentTag,
    );
  }

  String _generateComment(
    String summary,
    String? highlights,
    String? improvements,
    int energy,
    int mood,
    int taskCount,
  ) {
    final avg = (energy + mood) / 2;
    final hasHighlights =
        highlights != null && highlights.isNotEmpty && highlights != '没有';
    final hasSummary =
        summary.isNotEmpty && summary.length > 5;

    // 优先根据用户实际填写的内容生成回复
    if (hasHighlights) {
      final highlightPreview =
          highlights.length > 20 ? '${highlights.substring(0, 20)}…' : highlights;
      if (avg >= 3.5) {
        return _pick([
          '今天有「$highlightPreview」这样的收获，真不错！${
              _taskNote(taskCount)}心情和能量都在线，是充实的一天 🌟',
          '看到你今天「$highlightPreview」，为你感到开心！${
              _taskNote(taskCount)}保持这份状态，明天继续加油 💪',
        ]);
      }
      return _pick([
        '虽然今天状态一般，但「$highlightPreview」这件事做得很好！${
            _taskNote(taskCount)}生活中每一个小确幸都值得被记住 ✨',
        '有「$highlightPreview」这样的亮点就很棒了，${
            _taskNote(taskCount)}明天可以更好～',
      ]);
    }

    // 有总结内容的
    if (hasSummary) {
      if (avg >= 4.0) {
        return _pick([
          '今天整体感觉不错！$_taskNote 保持这样的节奏，继续加油 🔥',
          '状态很好的一天！$_taskNote 每天都像今天这样就很棒～✨',
        ]);
      } else if (avg >= 2.5) {
        return _pick([
          '今天过得还算平稳。$_taskNote 生活中最重要的就是保持这种节奏感 😊',
          '普通的一天也是生活的一部分，$_taskNote 接受每一个当下的自己 💪',
        ]);
      }
      return _pick([
        '今天可能有点疲惫，$_taskNote 好好休息，明天又是新的一天 🌙',
        '状态不太好也没关系，$_taskNote 累了就歇歇，身体最重要 🫂',
      ]);
    }

    // 没写什么内容时的兜底
    if (avg >= 4.0) {
      return _pick([
        '今天状态满分！$_taskNote 你是最棒的！🔥',
        '太棒了，双高分！$_taskNote 继续保持！✨',
      ]);
    } else if (avg >= 3.0) {
      return _pick([
        '状态不错！$_taskNote 稳住节奏，一切都在变好 🌤️',
        '不错的状态～$_taskNote 继续保持这种节奏！',
      ]);
    }
    return _pick([
      '今天可能有点累，$_taskNote 别忘了好好休息，明天满血复活 🌙',
      '今天辛苦了！$_taskNote 允许自己偶尔的低能量，充电后再出发 ⚡',
    ]);
  }

  String _taskNote(int count) {
    if (count >= 3) return '完成了 $count 项任务，效率不错～';
    if (count >= 1) return '完成了 $count 项任务，有在推进～';
    return '';
  }

  String _generateSuggestion(
    int energy,
    int mood,
    String? improvements,
    int taskCount,
    String summary,
  ) {
    final hasImprovements = improvements != null &&
        improvements.isNotEmpty &&
        improvements != '没有';
    final summaryMentionsRest = _containsAny(summary, ['休息', '睡觉', '累', '疲惫']);

    // 优先根据用户写的不足来给建议
    if (hasImprovements) {
      return _pick([
        '你提到的不足是个很好的反思切入点，明天可以试着在这方面做一些小改变 📈',
        '能发现自己的不足就是进步的开始，明天可以多留意一下 💪',
        '发现问题比没有问题更值得肯定，一步步来就好 👍',
      ]);
    }

    if (summaryMentionsRest || energy <= 2) {
      return _pick([
        '建议今晚早点休息，保证 7-8 小时睡眠，明天状态会好很多 😴',
        '能量偏低时不用强求效率，把最重要的 1-2 件事做好就够了 🎯',
        '今天早点睡吧，身体是革命的本钱 💪',
      ]);
    }
    if (mood <= 2) {
      return _pick([
        '情绪低落时可以盘盘串，重复性手部动作有助于缓解焦虑 🎯',
        '试试记录三件今天值得开心的小事，培养积极心态 ✍️',
        '如果心情不太好，和信任的朋友聊聊天会好很多 💬',
      ]);
    }
    if (taskCount == 0) {
      return _pick([
        '明天可以试试从最简单的一件待办开始，先完成再完美 🚀',
        '建议每天设定 1-3 个关键任务，优先完成最重要的那个 🎯',
      ]);
    }
    return _pick([
      '保持今天的节奏，明天可以挑战多完成一件待办事项 🎯',
      '每天花 10 分钟做复习，长期下来会有惊人的积累 📊',
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

    // 看看本周每天的亮点和不足，拼入概览
    final highlights =
        reviews.where((r) => r.highlights != null && r.highlights!.isNotEmpty && r.highlights != '没有').toList();
    final summarySnippets = reviews.take(3).map((r) =>
      '${r.date}: ${r.summary.length > 30 ? '${r.summary.substring(0, 30)}…' : r.summary}'
    ).toList();

    final avgDesc = (avgEnergy + avgMood) / 2 >= 3.5
        ? _pick(['整体状态不错', '状态良好', '度过了充实的一周'])
        : (avgEnergy + avgMood) / 2 >= 2.5
            ? _pick(['状态平稳', '有起有伏的一周', '稳中求进的一周'])
            : _pick(['有些疲惫的一周', '需要调整的一周']);

    final taskDesc = totalTasks > 10
        ? '完成了 $totalTasks 项任务，执行力很强'
        : totalTasks > 5
            ? '完成了 $totalTasks 项任务，有在持续推进'
            : '完成了 $totalTasks 项任务';

    final highlightDesc = highlights.isNotEmpty
        ? '其中 ${highlights.length} 天有亮点记录'
        : '建议下周多记录一些亮点和收获';

    final summaryDesc = summarySnippets.isNotEmpty
        ? '\n本周要点：${summarySnippets.join('；')}'
        : '';

    return '本周共复盘 $daysCount 天，$avgDesc。$taskDesc，$highlightDesc。'
        '平均能量 ${avgEnergy.toStringAsFixed(1)}/5，平均情绪 ${avgMood.toStringAsFixed(1)}/5。$summaryDesc';
  }

  String _generateWeekHighlights(List<DailyReviewSummary> reviews) {
    final items = <String>[];
    final highlights =
        reviews.where((r) => r.highlights != null && r.highlights!.isNotEmpty && r.highlights != '没有').toList();

    for (final r in highlights.take(3)) {
      items.add('• ${r.date}: ${r.highlights!.length > 25 ? '${r.highlights!.substring(0, 25)}…' : r.highlights}');
    }

    final highMood = reviews.where((r) => r.moodLevel >= 4).length;
    if (highMood > 0) items.add('• 有 $highMood 天情绪指数达到 4 分以上，心态积极');

    final highEnergy = reviews.where((r) => r.energyLevel >= 4).length;
    if (highEnergy > 0) items.add('• 有 $highEnergy 天能量充沛，状态在线');

    if (items.isEmpty) {
      items.addAll([
        '• 坚持每天做复盘，培养了自我反思的习惯',
        '• 对自身的状态有了更清晰的认知',
      ]);
    }

    return items.take(5).join('\n');
  }

  String _generateWeekImprovements(List<DailyReviewSummary> reviews) {
    final items = <String>[];
    final improvements =
        reviews.where((r) => r.improvements != null && r.improvements!.isNotEmpty && r.improvements != '没有').toList();

    for (final r in improvements.take(2)) {
      items.add('• ${r.date}: ${r.improvements!.length > 25 ? '${r.improvements!.substring(0, 25)}…' : r.improvements}');
    }

    final lowEnergy = reviews.where((r) => r.energyLevel <= 2).length;
    if (lowEnergy > 2) items.add('• 本周有 $lowEnergy 天能量偏低，建议关注作息规律');

    final lowMood = reviews.where((r) => r.moodLevel <= 2).length;
    if (lowMood > 2) items.add('• 有 $lowMood 天情绪偏低，可以尝试更多放松活动');

    final noTasks = reviews.where((r) => r.completedCount == 0).length;
    if (noTasks > 3) items.add('• 有 $noTasks 天未完成待办，建议每天设定最小可行目标');

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
    ];

    // 根据本周的实际表现生成有意义的建议
    if (reviews.isNotEmpty) {
      final avgEnergy = reviews.map((r) => r.energyLevel).reduce((a, b) => a + b) / reviews.length;
      if (avgEnergy < 3.0) items.add('• 调整作息时间，保证每天 7 小时以上睡眠');

      final lowMood = reviews.where((r) => r.moodLevel <= 2).length;
      if (lowMood > reviews.length / 3) items.add('• 尝试新的放松方式，如盘串、冥想或与朋友聚会');
    }

    items.addAll([
      '• ${_pick(["完成下周最重要的 3 个目标", "为下个月设定一个明确的方向"])}',
      '• ${_pick(["整理下周的待办清单，做到心中有数", "提前规划好下周的时间安排"])}',
    ]);

    return items.take(5).join('\n');
  }

  // ===== 工具方法 =====

  String _pick(List<String> options) {
    return options[DateTime.now().microsecondsSinceEpoch % options.length];
  }
}
