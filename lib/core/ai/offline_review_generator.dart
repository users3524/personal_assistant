library;

import 'dart:math';

import 'ai_service.dart';

/// 离线复盘生成器 — 2.0 升级版（纯本地模板引擎）
/// 融入了时间感知、文玩解压梗、更细腻的情绪交叉算法
class OfflineReviewGenerator implements AIService {
  @override
  Future<bool> isAvailable() async => true;

  // ===== 1. 聊天回复（支持根据时间段触发不同问候） =====

  @override
  Future<String> chat(String message) async {
    final msg = message.trim();
    if (msg.isEmpty) {
      return _pick([
        '可以聊聊今天的感受哦～',
        '我在听呢，今天过得怎么样？',
        '伸个懒腰，跟我说说今天的心情吧 🍃',
      ]);
    }

    // 动态时间前缀：让离线回复拥有"时间感知"
    final hour = DateTime.now().hour;
    final timePrefix = hour >= 22 ? '夜深了，' : (hour >= 18 ? '晚上好！' : '');

    if (_containsAny(msg, ['好', '嗯', 'ok', '可以', '是的', '对', 'yep'])) {
      return _pick([
        '${timePrefix}好的，继续聊聊今天的感受吧～',
        '嗯嗯，我听着呢，接下来呢？',
        '好的呢，今天还有什么想分享的吗？',
        '明白了，今天有什么让你印象深刻的事吗？',
        '收到～今天的你过得充实吗？',
      ], msg);
    }
    
    if (_containsAny(msg, ['没有', '没什么', '没啥', '没干啥'])) {
      return _pick([
        '${timePrefix}平平淡淡也是福～那咱们直接进入打分环节？',
        '没关系，普通的一天也值得记录，来给今天评个分吧！',
        '理解，生活不是每天都波澜壮阔的，来看看今天的整体能量？',
        '平淡的一天也挺好，静下心来盘盘串，顺便给今天打个分？ 🎯',
      ], msg);
    }
    
    if (_containsAny(msg, ['谢谢', '感谢', '辛苦了', '3q', 'thx'])) {
      return _pick([
        '不客气！看到你每天进步一点点，我也超开心的 😊',
        '冲鸭！今天也是积极营业的一天，明天会更好～',
        '棒棒哒，给自己鼓个掌，继续保持！',
        '应该的！在变好的路上陪着你，感觉真好 💪',
      ], msg);
    }
    
    if (_containsAny(msg, ['累', '烦', '压力', '忙', '疲惫', '困', '熬夜', '撑不住'])) {
      return _pick([
        '${timePrefix}辛苦了！快放下手里的活，给大脑放个假，盘盘手串解解压 🎯',
        '压力大说明你一直在对自己有要求，你已经做得很好了，抱抱！',
        '生活不易，但你今天撑过来了，每一个小坚持都闪闪发光 💪',
        '累了就彻底躺平一会儿，身体和心情永远是第一位的～',
        '快去喝杯温水、闭眼冥想两分钟，或者揉揉太阳穴放松一下 🌿',
        if (hour >= 22) '熬夜伤身，今晚要不早点把灯关了，早点休息吧 🌙',
      ], msg);
    }
    
    if (_containsAny(msg, ['开心', '高兴', '顺利', '成功', '完成', '棒', '不错', '赚', '嗨'])) {
      return _pick([
        '太棒了！屏幕这头的我都感受到你的快乐了，今天收获满满呀 🎉',
        '真好！听到你这么顺心，我今天也值了～请务必保持这份状态！',
        '厉害了我的友！今天状态拉满，执行力简直爆表 🚀',
        'Nice！今天的表现值得去吃顿好的，或者给自己加个鸡腿 👍',
        '顺风顺水的一天，感觉手里的串都变得更有光泽了呢 ✨',
      ], msg);
    }
    
    if (_containsAny(msg, ['生气', '难过', '伤心', '郁闷', '焦虑', '烦躁', '哭', 'emo'])) {
      return _pick([
        '抱抱你，允许自己有低谷和负面情绪，我一直在这听你说 🤗',
        '把不开心的事写出来，也是一种心理排毒，我在听着呢～',
        '情绪的暴风雨总会过去的，今天你顶住压力，辛苦了 🫂',
        '有什么我能帮上忙的吗？如果觉得烦，不如试着深呼吸三次 💙',
        '摸摸头，生活偶尔会开玩笑，今晚奖励自己早点休息好不好？',
      ], msg);
    }
    
    if (_containsAny(msg, ['盘串', '盘玩', '核桃', '手串', '星月', '金刚', '文玩', '菩提'])) {
      return _pick([
        '盘串解压效果妥妥的第一名！今天把它盘包浆了吗？🎯',
        '文玩人的快乐就是这么朴实无华且枯燥～',
        '手指动起来的时候，杂念就静下来了。感觉现在心情好点了吗？😌',
        '越盘越润，人也越活越通透，这就是文玩的魅力吧 🌿',
      ], msg);
    }
    
    if (_containsAny(msg, ['复盘', '保存', '确认', '搞定', '提交'])) {
      return _pick([
        '好嘞，账目已清，准备为你复盘保存啦～',
        '收到指令！是否确认封存今天的记忆？',
        '没问题，把今天的成长妥妥地存进小本本里！',
      ], msg);
    }

    // 兜底回复
    return _pick([
      '收到！信息量很大，继续说说看？',
      '原来是这样，我认真记下了，还有要补充的吗？',
      '听起来是个有故事的一天，接着说，我在听～',
      '嗯嗯，这个细节很有意思，然后呢？',
      '好的，今天除了这些，还有什么想念叨的吗？',
    ], msg);
  }

  bool _containsAny(String text, List<String> keywords) {
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
  }

  // ===== 2. 日报生成（基于多条件交叉判断） =====

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
    final taskCount = completedTitles.length;
    final comment = _generateComment(summary, highlights, improvements, energyLevel, moodLevel, taskCount, pattingMinutes);
    final suggestion = _generateSuggestion(energyLevel, moodLevel, improvements, taskCount, summary, pattingMinutes);
    final sentimentTag = _generateTag(energyLevel, moodLevel, taskCount);

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
    int pattingMinutes,
  ) {
    final avg = (energy + mood) / 2;
    final hasHighlights = highlights != null && highlights.isNotEmpty && highlights != '没有';
    final hasSummary = summary.isNotEmpty && summary.length > 5;
    final seed = summary + (highlights ?? '') + improvements.toString();

    // 文玩特色串联句
    final pattingNote = pattingMinutes > 0 ? '今天还抽空盘串了 $pattingMinutes 分钟，可以说是劳逸结合的典范了。' : '';

    // 🌟 场景一：用户填写了闪光点/收获
    if (hasHighlights) {
      final highlightPreview = highlights.length > 25 ? '${highlights.substring(0, 25)}…' : highlights;
      if (avg >= 3.5) {
        return _pick([
          '核心收获聚焦在「$highlightPreview」，含金量很高！${_taskNote(taskCount)} $pattingNote 状态和执行力双在线，请保持这个势头，明天继续发光发热 🌟',
          '为你今天取得的「$highlightPreview」成果感到骄傲！${_taskNote(taskCount)} 目标明确且稳扎稳打，真是高产又高效的一天 💪',
        ], seed);
      }
      return _pick([
        '虽然今天在精力或情绪上有些许波动，但你能抓住「$highlightPreview」这个闪光点就非常了不起！${_taskNote(taskCount)} 留心生活中的小确幸，它会成为你触底反弹的养分 ✨',
        '状态一般的时候往往能磨练心智，今天做到了「$highlightPreview」，这就是硬实力的体现。${_taskNote(taskCount)} 辛苦了，明天调整状态再出发！',
      ], seed);
    }

    // 📝 场景二：无特定亮点，但写了较为详细的总结
    if (hasSummary) {
      if (avg >= 4.0) {
        return _pick([
          '根据你的总结来看，今天整体运转得非常顺畅！${_taskNote(taskCount)} $pattingNote 能量满格，节奏感把控得炉火纯青，继续保持这种顶峰状态 🔥',
          '极其舒适的一天！你在总结中展现了极强的行动力。${_taskNote(taskCount)} 每天都维持这样清爽高效的节奏，离目标就不远了 🚀',
        ], seed);
      } else if (avg >= 2.5) {
        return _pick([
          '今天过得还算平稳踏实。${_taskNote(taskCount)} $pattingNote 生活的常态就是清水长流，保持住这种不疾不徐的复利节奏，也是一种大智慧 😊',
          '属于在主线上稳步推进的一天。虽然没有特别惊艳的事，但各方面都交代得过去。${_taskNote(taskCount)} 接受每个阶段的自己，做长期主义者 💪',
        ], seed);
      }
      return _pick([
        '看得出今天你感到有些累了。总结里的字里行间透着一丝疲惫。${_taskNote(taskCount)} 状态有高低起伏很正常，今天允许自己电量探底，好好睡一觉 🌙',
        '今天可能遇到了一点小挑战或情绪低谷。${_taskNote(taskCount)} 别把自己逼得太紧，身体和心态才是最核心的资产。今晚就把工作抛到脑后吧 🫂',
      ], seed);
    }

    // 📥 场景三：纯打分，没写什么字（兜底模板群）
    if (avg >= 4.5) {
      return _pick(['今天简直是战神下凡！状态直接拉满 🌟 ${_taskNote(taskCount)} 这种极佳的状态要好好复盘并记住它！', '双五分！又是被幸运和高效包围的一天。${_taskNote(taskCount)} $pattingNote 今天的你无懈可击！✨'], seed);
    } else if (avg >= 3.0) {
      return _pick(['整体状态良好，一切尽在掌握。${_taskNote(taskCount)} 稳扎稳打，明天的你依然可以做得很棒！🌤️', '不错的一天，能量值很健康。${_taskNote(taskCount)} 继续保持这种松弛有度的节奏，生活才会更有弹性。'], seed);
    }
    return _pick(['今天辛苦了，可能电量不太够。${_taskNote(taskCount)} 哪怕什么都没做也不要焦虑，今晚好好充电，明天又是满血复活的一天 🔋', '有些低迷的一天，但没关系。允许自己偶尔停下脚步歇一歇，毕竟弦拉得太紧容易断 🤝']);
  }

  String _taskNote(int count) {
    if (count >= 5) return '一口气斩获了 $count 项任务，简直是效率收割机！';
    if (count >= 3) return '高效完成了 $count 项任务，执行力很能打～';
    if (count >= 1) return '完成了 $count 项任务，核心主线有在踏实推进～';
    return '虽然今天没有勾选完成的任务，但并不妨碍我们积蓄能量。';
  }

  String _generateSuggestion(
    int energy,
    int mood,
    String? improvements,
    int taskCount,
    String summary,
    int pattingMinutes,
  ) {
    final hasImprovements = improvements != null && improvements.isNotEmpty && improvements != '没有';
    final isLowEnergy = energy <= 2;
    final isLowMood = mood <= 2;
    final seed = summary + (improvements ?? '') + taskCount.toString();

    // 1. 优先解决用户明确指出的"不足"
    if (hasImprovements) {
      return _pick([
        '你提到的不足「$improvements」直击痛点，能直面问题就赢了一半。明天可以试着把这个问题拆解成一步能完成的小动作，降低执行门槛 📈',
        '发现漏洞就是升级的契机。针对你指出的不足，明天不妨多留个心眼，刻意练习一下，稳扎稳打 💪',
        '知耻近乎勇，知不足而能自省。别气馁，明天针对这一点稍微做个微调就好 👍',
      ], seed);
    }

    // 2. 状态预警优先（累了、疲惫了）
    if (_containsAny(summary, ['休息', '睡觉', '累', '疲惫']) || isLowEnergy) {
      return _pick([
        '高能耗后必须有深度拉伸和休息。强烈建议今晚执行「数字化排毒」，提前半小时放下手机，保证 7 小时以上优质睡眠 😴',
        '当前处于低电量模式，明天不要给自己排太满的日程。抓大放小，集中精力只攻克最重要的一件事即可 🎯',
        '身体已经发出信号了，今天早点洗个热水澡睡吧。留得青山在，不怕没柴烧 ☕',
      ], seed);
    }

    // 3. 心情调理建议
    if (isLowMood) {
      if (pattingMinutes < 5) {
        return _pick([
          '心情低落时，思维容易打结。推荐去把你的手串拿出来狠盘 10 分钟，指尖的触感和重复性动作可以有效刺激多巴胺，缓解焦虑 🎯',
          '试着找个无人的地方深呼吸，或者在本子上盲写出三个愤怒/难过的原因然后划掉它。让情绪流淌出来，不要内耗 ✍️',
        ], seed);
      }
      return _pick([
        '今天已经盘串解压了，如果心情还没好转，不妨换个环境，去楼下散散步，或者找信任的朋友吐吐槽，把负能量倒出来 💬',
        '情绪低落时千万不要复盘复杂的工作，允许自己今天及格就行。去听一首节奏欢快的歌或者看个搞笑视频吧 🎧',
      ], seed);
    }

    // 4. 执行力与任务导向建议
    if (taskCount == 0) {
      return _pick([
        '明天试着用"两分钟法则"：任何两分钟内能搞定的事，睁眼就把它干掉。先用微小的胜利把自信心和执行状态带起来 🚀',
        '明天建议在手账或清单上明确写下核心的"三剑客任务"（Top 3 Tasks），做完一个勾一个，防止精力分散 🎯',
      ], seed);
    }

    // 5. 状态极佳时的更进一步建议
    return _pick([
      '目前的节奏非常完美，明天可以尝试挑战一个之前一直拖延的"硬骨头"任务，乘胜追击 🎯',
      '每天花 5-10 分钟整理今天沉淀下来的产物或文档，长期积累下来，你会拥有一座惊人的个人知识库 📊',
      '优秀已经成为你的习惯，保持这个复盘频率，持续记录自己的成长轨迹 ⏰',
    ], seed);
  }

  String _generateTag(int energy, int mood, int taskCount) {
    final avg = (energy + mood) / 2;
    if (avg >= 4.2 && taskCount >= 3) return '战神拉满';
    if (avg >= 4.0) return '元气满满';
    if (taskCount >= 4) return '肝帝附体';
    if (avg >= 3.0) return '稳中求进';
    if (mood <= 2) return '情绪感冒';
    if (energy <= 2) return '急需充电';
    return '平静如水';
  }

  // ===== 3. 周报生成（多数据深度聚合与趋势分析） =====

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
      return '本周记录一片空白。成长需要痕迹，下周不妨从每天花 1 分钟打分开始，慢慢建立你的复盘习惯吧 💡。';
    }

    final daysCount = reviews.length;
    final avgEnergy = reviews.map((r) => r.energyLevel).reduce((a, b) => a + b) / daysCount;
    final avgMood = reviews.map((r) => r.moodLevel).reduce((a, b) => a + b) / daysCount;
    final totalTasks = reviews.fold<int>(0, (sum, r) => sum + r.completedCount);
    
    // 聚合本周的高频片段
    final validHighlights = reviews.where((r) => r.highlights != null && r.highlights!.isNotEmpty && r.highlights != '没有').toList();
    final topSnippets = reviews.take(3).map((r) => '[${r.date}] ${r.summary.length > 20 ? '${r.summary.substring(0, 20)}…' : r.summary}').toList();

    // 状态综合评估
    final combinedScore = (avgEnergy + avgMood) / 2;
    String statusDesc;
    if (combinedScore >= 4.0) {
      statusDesc = '犹如开了挂的一周，身心状态极佳';
    } else if (combinedScore >= 3.2) {
      statusDesc = '节奏平稳开阔，各方面平衡得很好';
    } else if (combinedScore >= 2.5) {
      statusDesc = '有起有伏，在波折中稳步前行';
    } else {
      statusDesc = '身心严重超载，亮起低电量红灯';
    }

    final taskDesc = totalTasks >= 15
        ? '疯狂搞定了 $totalTasks 项任务，执行力堪称劳模'
        : (totalTasks >= 5 ? '稳步推进了 $totalTasks 项任务，节奏踩得很准' : '累计完成了 $totalTasks 项具体事务');

    final summarySection = topSnippets.isNotEmpty ? '\n📅 本周主线脉络：\n${topSnippets.join('\n')}' : '';

    return '✨ 本周复盘盘点：本周一共坚持复盘了 $daysCount 天，$statusDesc。'
        '在此期间，你$taskDesc；其中有 ${validHighlights.length} 天留下了高光闪光点。'
        '整体平均能量指数 ${avgEnergy.toStringAsFixed(1)}/5，平均情绪指数 ${avgMood.toStringAsFixed(1)}/5。'
        '质量很高的一周，辛苦了！$summarySection';
  }

  String _generateWeekHighlights(List<DailyReviewSummary> reviews) {
    final items = <String>[];
    final highlights = reviews.where((r) => r.highlights != null && r.highlights!.isNotEmpty && r.highlights != '没有').toList();

    for (final r in highlights.take(3)) {
      items.add('• 高光 [${r.date}]：${r.highlights!.length > 30 ? '${r.highlights!.substring(0, 30)}…' : r.highlights}');
    }

    final highMoodDays = reviews.where((r) => r.moodLevel >= 4).length;
    if (highMoodDays > 0) items.add('• 心态高光：本周有 $highMoodDays 天心情处于高位，正向情绪极具感染力。');

    final highEnergyDays = reviews.where((r) => r.energyLevel >= 4).length;
    if (highEnergyDays > 0) items.add('• 能量高光：本周有 $highEnergyDays 天高能输出，攻克了不少硬骨头。');

    if (items.isEmpty) {
      items.addAll([
        '• 习惯建立：坚持完成了多日的自我对话和复盘，这就是本周最大的高光。',
        '• 觉察提升：对自身的能量边界有了更清晰、理性的认知。',
      ]);
    }

    return items.take(5).join('\n');
  }

  String _generateWeekImprovements(List<DailyReviewSummary> reviews) {
    final items = <String>[];
    final improvements = reviews.where((r) => r.improvements != null && r.improvements!.isNotEmpty && r.improvements != '没有').toList();

    for (final r in improvements.take(2)) {
      items.add('• 待改进 [${r.date}]：${r.improvements!.length > 30 ? '${r.improvements!.substring(0, 30)}…' : r.improvements}');
    }

    final lowEnergyDays = reviews.where((r) => r.energyLevel <= 2).length;
    if (lowEnergyDays >= 3) items.add('• 警告：本周有 $lowEnergyDays 天处于严重低能量状态，作息或工作强度亟待调整。');

    final lowMoodDays = reviews.where((r) => r.moodLevel <= 2).length;
    if (lowMoodDays >= 3) items.add('• 关注：本周情绪低落天数达到 $lowMoodDays 天，请注意识别压力源，谨防内耗。');

    final blankTaskDays = reviews.where((r) => r.completedCount == 0).length;
    if (blankTaskDays >= 4) items.add('• 推进受阻：本周过半天数未勾选任务，需警惕虚假忙碌，注意细化目标。');

    if (items.isEmpty) {
      items.addAll([
        '• 颗粒度优化：下周可以尝试更详细地记录亮点与不足，让复盘数据更饱满。',
        '• 目标对齐：注意检查每日任务是否真正服务于你的长期周目标。',
      ]);
    }

    return items.take(3).join('\n');
  }

  String _generateWeekPlan(List<DailyReviewSummary> reviews) {
    final items = <String>[
      '• 【核心习惯】雷打不动地延续每日复盘，保持思想的清爽度。',
    ];

    if (reviews.isNotEmpty) {
      final avgEnergy = reviews.map((r) => r.energyLevel).reduce((a, b) => a + b) / reviews.length;
      if (avgEnergy < 3.2) {
        items.add('• 【健康充电】强制执行睡眠防火墙，下周至少有 3 天在 23:30 前熄灯。');
      }
      
      final lowMoodCount = reviews.where((r) => r.moodLevel <= 2).length;
      if (lowMoodCount > 2) {
        items.add('• 【心态减负】下周设置固定的文玩包浆/冥想解压时间，主动切断高压源。');
      }
    }

    final seed = reviews.length.toString();
    items.addAll([
      '• 【精准打击】${_pick(["聚焦攻克下周最重要的 3 个硬核指标，不摊大饼", "围绕一个核心痛点发力，集中兵力打歼灭战"], seed)}',
      '• 【周中复盘】${_pick(["在周三或周四做一次年中微调，防止周尾抱佛脚", "优化下周的时间清单，留出 20% 的空白防御时间"], seed)}',
    ]);

    return items.take(5).join('\n');
  }

  // ===== 4. 工具方法 =====

  final Random _random = Random();

  /// 强化版的随机/半确定性选择器
  String _pick(List<String> options, [String? seed]) {
    if (options.isEmpty) return '';
    int index;
    if (seed != null && seed.trim().isNotEmpty) {
      // 融合哈希码与 10 秒级时间戳，保证同一段话在短时间内重新生成具有稳定性，过段时间又有新鲜感
      final timeSlice = DateTime.now().millisecondsSinceEpoch ~/ 10000;
      index = (seed.hashCode.abs() + timeSlice) % options.length;
    } else {
      index = _random.nextInt(options.length);
    }
    return options[index];
  }
}
