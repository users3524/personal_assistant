/// 复盘对话页 — 对话问答式日复盘。
///
/// 用户通过文字或语音输入每天的总结和感受，
/// AI 以对话方式引导复盘，最终生成结构化日报并保存。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../../../core/ai/ai_provider.dart';
import '../../../../core/ai/llm_strategy_config.dart';
import '../../../../core/ai/prompt_builder.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/chat_turn_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../../../collection/presentation/providers/antique_providers.dart';
import '../../../todo/presentation/providers/todo_providers.dart';

// ===== 对话消息模型 =====

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, DateTime? time})
    : time = time ?? DateTime.now();
}

// ===== 页面 =====

class DailyReviewChatPage extends ConsumerStatefulWidget {
  final String? dateStr; // 编辑已有复盘时传入日期

  const DailyReviewChatPage({super.key, this.dateStr});

  @override
  ConsumerState<DailyReviewChatPage> createState() =>
      _DailyReviewChatPageState();
}

class _DailyReviewChatPageState extends ConsumerState<DailyReviewChatPage> {
  static const _maxTextInputLength = 500;
  static const _chatTurnSource = 'daily_review_chat';

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <ChatMessage>[];
  bool _isProcessing = false;
  bool _reviewSaved = false;

  // 复盘数据
  int _energyLevel = 3;
  int _moodLevel = 3;
  String _summary = '';
  String _highlights = '';
  String _improvements = '';
  String _aiComment = '';
  String _aiSuggestion = '';

  // AI 对话状态
  int _flowStep = 0; // 0=等待首次输入, 1=收集收获, 2=收集不足, 3=评分, 4=AI分析, 5=完成
  bool _awaitingConfirmation = false;

  // 语音识别
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';
  Timer? _speechCutoffTimer;

  // 编辑模式
  DailyReviewEntity? _existingReview;

  @override
  void initState() {
    super.initState();
    _loadIfEditing();
    _addWelcomeMessage();
  }

  Future<void> _loadIfEditing() async {
    if (widget.dateStr == null) return;
    final date = DateTime.parse(widget.dateStr!);
    final repo = await ref.read(reviewRepositoryProvider.future);
    final review = await repo.getDailyByDate(date);
    if (review != null && mounted) {
      setState(() {
        _existingReview = review;
        _summary = review.summary;
        _highlights = review.highlights ?? '';
        _improvements = review.improvements ?? '';
        _energyLevel = review.energyLevel;
        _moodLevel = review.moodLevel;
        _aiComment = review.aiComment ?? '';
        _aiSuggestion = review.aiSuggestion ?? '';
        // 显示已有内容
        _messages.clear();
        _messages.add(
          ChatMessage(
            text: '📋 以下是 ${date.month}/${date.day} 的已有复盘记录',
            isUser: false,
          ),
        );
        _messages.add(ChatMessage(text: '总结：$_summary', isUser: false));
        if (_highlights.isNotEmpty) {
          _messages.add(ChatMessage(text: '收获：$_highlights', isUser: false));
        }
        if (_improvements.isNotEmpty) {
          _messages.add(ChatMessage(text: '不足：$_improvements', isUser: false));
        }
        _messages.add(ChatMessage(text: '✨ AI 评语：$_aiComment', isUser: false));
        _messages.add(
          ChatMessage(text: '💡 AI 建议：$_aiSuggestion', isUser: false),
        );
        if (_aiComment.isNotEmpty) _reviewSaved = true;
      });
    }
  }

  void _addWelcomeMessage() {
    if (widget.dateStr != null && _existingReview != null) return;
    _messages.add(
      ChatMessage(
        text:
            '👋 今天过得怎么样？跟我说说今天的经历和感受吧！\n\n'
            '你可以输入文字或点击麦克风语音输入。',
        isUser: false,
      ),
    );
  }

  /// 核心对话处理 — 自然语言驱动，AI 全程参与
  Future<void> _sendMessage(String text) async {
    final userText = _normalizeInputText(text);

    if (userText.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isProcessing = true;
    });
    _scrollToBottom();

    // 检测保存确认
    if (_awaitingConfirmation && _aiComment.isNotEmpty) {
      if (userText.contains('确认') ||
          userText.contains('保存') ||
          userText.contains('好') ||
          userText.contains('是')) {
        await _saveReview();
        setState(() => _isProcessing = false);
        return;
      }
    }

    // 根据当前步骤引导对话
    switch (_flowStep) {
      case 0: // 首次输入 → 作为总结
        await _handleStep0(userText);
        break;
      case 1: // 收集收获
        await _handleStep1(userText);
        break;
      case 2: // 收集不足
        await _handleStep2(userText);
        break;
      case 3: // 评分阶段
        await _handleStep3(userText);
        break;
      case 4: // AI 已生成 → 可继续对话或保存
        await _handleStep4(userText);
        break;
      case 5: // 已完成
        _addBotMessage('复盘已保存。你可以继续聊天，或者返回查看历史记录。');
        setState(() => _isProcessing = false);
        break;
    }
  }

  Future<void> _handleStep0(String text) async {
    _summary = text;
    setState(() {
      _flowStep = 1;
      _messages.add(
        ChatMessage(
          text:
              '收到！今天有什么特别开心的收获或成就吗？🥰\n'
              '（也可以直接告诉我"没有"）',
          isUser: false,
        ),
      );
      _isProcessing = false;
    });
  }

  Future<void> _handleStep1(String text) async {
    if (text == '没有' || text == '无' || text == '暂无') {
      _highlights = '今天平稳度过';
    } else {
      _highlights = text;
    }
    setState(() {
      _flowStep = 2;
      _messages.add(
        ChatMessage(
          text:
              '好的！那有什么不足或想改进的地方吗？🤔\n'
              '（诚实面对自己才能成长，也可以说"没有"）',
          isUser: false,
        ),
      );
      _isProcessing = false;
    });
  }

  Future<void> _handleStep2(String text) async {
    if (text == '没有' || text == '无' || text == '暂无') {
      _improvements = '';
    } else {
      _improvements = text;
    }
    setState(() {
      _flowStep = 3;
      _messages.add(
        ChatMessage(
          text:
              '感谢你的坦诚！给你的今天打个分吧：\n\n'
              '😊 情绪指数（1-5）：目前 $_moodLevel\n'
              '⚡ 能量指数（1-5）：目前 $_energyLevel\n\n'
              '回复「确认」使用当前评分，或输入「情绪4 能量3」来修改',
          isUser: false,
        ),
      );
      _isProcessing = false;
    });
  }

  Future<void> _handleStep3(String text) async {
    // 解析评分
    final moodMatch = RegExp(r'情绪[：:\s]*(\d)').firstMatch(text);
    final energyMatch = RegExp(r'能量[：:\s]*(\d)').firstMatch(text);

    if (moodMatch != null) {
      _moodLevel = int.parse(moodMatch.group(1)!).clamp(1, 5);
    }
    if (energyMatch != null) {
      _energyLevel = int.parse(energyMatch.group(1)!).clamp(1, 5);
    }

    if (text.contains('确认') ||
        text.contains('好') ||
        text.contains('可以') ||
        text.contains('是')) {
      // 进入 AI 生成阶段
      setState(() {
        _flowStep = 4;
        _messages.add(
          ChatMessage(
            text:
                '好的，情绪：$_moodLevel ⭐  能量：$_energyLevel ⚡\n\n'
                '正在为你生成 AI 复盘分析...',
            isUser: false,
          ),
        );
      });
      await _generateReview();
    } else if (moodMatch != null || energyMatch != null) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                '已更新：情绪 $_moodLevel ⭐  能量 $_energyLevel ⚡\n'
                '回复「确认」开始 AI 分析，或继续修改。',
            isUser: false,
          ),
        );
        _isProcessing = false;
      });
    } else {
      setState(() {
        _messages.add(
          ChatMessage(text: '请用「情绪数字 能量数字」的格式，或直接回复「确认」。', isUser: false),
        );
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleStep4(String text) async {
    // AI 已生成，用户可以继续对话
    final ai = ref.read(aiServiceProvider);
    if (ai != null) {
      try {
        final usesCloud = _usesCloudAI();
        if (usesCloud) {
          final decision = await _decideOnlineDelivery();
          if (!decision.shouldCallCloud) {
            await _recordChatTurn(
              role: 'user',
              content: text,
              isOffline: true,
              consumesCloudTurn: false,
            );
            _addBotMessage('${decision.reason}，我已把这条记为离线便签。');
            setState(() => _isProcessing = false);
            return;
          }
        }
        await _recordChatTurn(
          role: 'user',
          content: text,
          isOffline: !usesCloud,
          consumesCloudTurn: usesCloud,
        );
        final reply = await ai.chat(
          '以下是我的今日复盘：\n'
          '总结：$_summary\n'
          '收获：$_highlights\n'
          '不足：${_improvements.isEmpty ? "无" : _improvements}\n'
          '情绪：$_moodLevel/5 能量：$_energyLevel/5\n'
          'AI评语：$_aiComment\n'
          'AI建议：$_aiSuggestion\n\n'
          '用户说：$text\n\n'
          '请以温暖、专业的口吻简短回复（50字以内）。',
        );
        await _recordChatTurn(
          role: 'assistant',
          content: reply,
          isOffline: !usesCloud,
        );
        _addBotMessage(reply);
      } catch (_) {
        _addBotMessage('收到！你可以继续和我聊，或者回复「保存」来保存复盘。');
      }
    } else {
      await _recordChatTurn(role: 'user', content: text, isOffline: true);
      _addBotMessage('收到！你可以回复「保存」来保存当前复盘。');
    }
    setState(() => _isProcessing = false);
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });
  }

  Future<void> _generateReview() async {
    final ai = ref.read(aiServiceProvider);
    if (ai == null) {
      await _recordChatTurn(role: 'user', content: _summary, isOffline: true);
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                '⚠️ 请先在「设置」页面配置 AI API Key，然后才能使用 AI 智能分析功能。\n\n'
                '配置方法：\n'
                '1. 前往设置 → AI 配置\n'
                '2. 选择 AI 平台（推荐 DeepSeek，便宜好用）\n'
                '3. 填入 API Key 和模型\n\n'
                '（当前可以手动填写内容后保存）',
            isUser: false,
          ),
        );
        _isProcessing = false;
        _awaitingConfirmation = true;
      });
      return;
    }

    try {
      // 获取今日已完成待办
      final todoRepo = await ref.read(todoRepositoryProvider.future);
      final todayTodos = await todoRepo.getToday();
      final completedTitles = todayTodos
          .where((t) => t.isDone)
          .map((t) => t.title)
          .toList();
      final reviewDate = _targetReviewDate();
      final pattingMinutes = await _loadPattingMinutes(reviewDate);

      final usesCloud = _usesCloudAI();
      if (usesCloud) {
        final decision = await _decideOnlineDelivery();
        if (!decision.shouldCallCloud) {
          await _recordChatTurn(
            role: 'user',
            content: _summary,
            isOffline: true,
            consumesCloudTurn: false,
          );
          setState(() {
            _messages.add(
              ChatMessage(
                text: '${decision.reason}，本次不再请求云端；我已把内容作为离线便签保留。',
                isUser: false,
              ),
            );
            _isProcessing = false;
            _awaitingConfirmation = true;
          });
          return;
        }
      }

      await _recordChatTurn(
        role: 'user',
        content: _summary,
        isOffline: !usesCloud,
        consumesCloudTurn: usesCloud,
      );

      // 调用 AI
      final result = await ai.generateDailyReview(
        summary: _summary,
        highlights: _highlights,
        improvements: _improvements,
        energyLevel: _energyLevel,
        moodLevel: _moodLevel,
        completedTitles: completedTitles,
        pattingMinutes: pattingMinutes,
      );

      setState(() {
        _aiComment = result.comment;
        _aiSuggestion = result.suggestion;
        _awaitingConfirmation = true;

        final improvementNote = _improvements.isNotEmpty
            ? '\n\n📌 **可改进点（已置顶）**：\n$_improvements'
            : '';

        _messages.add(
          ChatMessage(
            text:
                '✨ **AI 复盘分析**\n\n'
                '📝 评语：${result.comment}\n\n'
                '💡 建议：${result.suggestion}\n\n'
                '🏷️ 情绪标签：${result.sentimentTag}'
                '$improvementNote\n\n'
                '———\n'
                '回复「确认」或「保存」来保存本次复盘 ✅\n'
                '也可以继续和我聊聊你的想法 💬',
            isUser: false,
          ),
        );
        _isProcessing = false;
      });
      await _recordChatTurn(
        role: 'assistant',
        content:
            '${result.comment}\n${result.suggestion}\n${result.sentimentTag}',
        isOffline: !usesCloud,
      );
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                '❌ AI 生成失败：$e\n\n'
                '可能是网络问题或 API Key 无效。\n'
                '请检查设置中的 AI 配置。\n'
                '你也可以手动填写后保存。',
            isUser: false,
          ),
        );
        _isProcessing = false;
        _awaitingConfirmation = true;
      });
    }
  }

  Future<PromptDeliveryDecision> _decideOnlineDelivery() async {
    final config = ref.read(aiConfigProvider);
    final dao = await ref.read(chatTurnDaoProvider.future);
    final turnDate = _turnDateString(_targetReviewDate());
    final usedTurns = await dao.countCloudTurns(turnDate);
    return PromptBuilder(strategy: config.strategy).decideDelivery(
      onlineTurnsUsedToday: usedTurns,
      apiConfigured: config.apiKey.isNotEmpty,
    );
  }

  bool _usesCloudAI() {
    final config = ref.read(aiConfigProvider);
    return config.provider != LLMStrategyConfig.offlineProvider &&
        config.apiKey.trim().isNotEmpty;
  }

  Future<void> _recordChatTurn({
    required String role,
    required String content,
    bool isOffline = false,
    bool consumesCloudTurn = false,
  }) async {
    final dao = await ref.read(chatTurnDaoProvider.future);
    await dao.insert(
      ChatTurnEntity(
        turnDate: _turnDateString(_targetReviewDate()),
        role: role,
        content: content,
        isOffline: isOffline,
        consumesCloudTurn: consumesCloudTurn,
        source: _chatTurnSource,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _saveReview() async {
    if (_reviewSaved) {
      _showSnack('已保存');
      return;
    }

    try {
      final repo = await ref.read(reviewRepositoryProvider.future);
      final reviewDate = _targetReviewDate();
      final pattingMinutes = await _loadPattingMinutes(reviewDate);

      if (_existingReview != null) {
        // 更新
        await repo.updateDaily(
          _existingReview!.copyWith(
            summary: _summary,
            highlights: _highlights.isNotEmpty ? _highlights : null,
            improvements: _improvements.isNotEmpty ? _improvements : null,
            energyLevel: _energyLevel,
            moodLevel: _moodLevel,
            pattingMinutes: pattingMinutes,
            aiComment: _aiComment.isNotEmpty ? _aiComment : null,
            aiSuggestion: _aiSuggestion.isNotEmpty ? _aiSuggestion : null,
          ),
        );
      } else {
        // 新建
        final now = DateTime.now();
        await repo.createDaily(
          DailyReviewEntity(
            date: reviewDate,
            summary: _summary,
            highlights: _highlights.isNotEmpty ? _highlights : null,
            improvements: _improvements.isNotEmpty ? _improvements : null,
            energyLevel: _energyLevel,
            moodLevel: _moodLevel,
            pattingMinutes: pattingMinutes,
            aiComment: _aiComment.isNotEmpty ? _aiComment : null,
            aiSuggestion: _aiSuggestion.isNotEmpty ? _aiSuggestion : null,
            isAiGenerated: _aiComment.isNotEmpty,
            isManuallyEdited: _aiComment.isEmpty,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      setState(() {
        _reviewSaved = true;
        _flowStep = 5;
        _awaitingConfirmation = false;
      });
      _messages.add(ChatMessage(text: '✅ 复盘已保存！', isUser: false));

      // 刷新 provider
      ref.invalidate(reviewRepositoryProvider);
      ref.invalidate(aiConfigProvider);

      _showSnack('复盘已保存');
    } catch (e) {
      _showSnack('保存失败: $e');
    }
  }

  // ===== 语音输入 =====

  Future<void> _startListening() async {
    final available = await _speech.initialize();
    if (!available) {
      _showSnack('语音识别不可用');
      return;
    }
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (result) {
        setState(() => _lastWords = result.recognizedWords);
        _msgCtrl.text = _lastWords;
      },
      listenOptions: stt.SpeechListenOptions(localeId: 'zh_CN'),
    );
    _speechCutoffTimer?.cancel();
    _speechCutoffTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted || !_isListening) return;
      _stopListening();
      _showSnack('语音已达到 60 秒上限，已自动发送当前识别内容');
    });
  }

  void _stopListening() {
    _speechCutoffTimer?.cancel();
    _speechCutoffTimer = null;
    _speech.stop();
    setState(() => _isListening = false);
    if (_lastWords.isNotEmpty) {
      _sendMessage(_lastWords);
      _msgCtrl.clear();
      _lastWords = '';
    }
  }

  // ===== UI =====

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _speechCutoffTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _handleTextMessage(String text) {
    final lower = text.trim().toLowerCase();

    // 保存确认
    if (_awaitingConfirmation && _aiComment.isNotEmpty) {
      if (lower.contains('确认') ||
          lower.contains('保存') ||
          lower.contains('好') ||
          lower.contains('是')) {
        _saveReview();
        return;
      }
    }

    // 评分阶段特殊处理
    if (_flowStep == 3) {
      if (RegExp(r'情绪|能量|确认|好|可以|是').hasMatch(lower)) {
        _sendMessage(text);
        return;
      }
    }

    _sendMessage(text);
  }

  String _normalizeInputText(String text) {
    final trimmed = text.trim();
    if (trimmed.runes.length <= _maxTextInputLength) {
      return trimmed;
    }
    _showSnack('单次输入最多 500 字，已自动截断');
    return String.fromCharCodes(trimmed.runes.take(_maxTextInputLength));
  }

  DateTime _targetReviewDate() {
    if (widget.dateStr != null) {
      final parsed = DateTime.parse(widget.dateStr!);
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _turnDateString(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Future<int> _loadPattingMinutes(DateTime date) async {
    final repo = await ref.read(antiqueRepositoryProvider.future);
    return repo.sumPattingMinutesByDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.dateStr != null
        ? DateTime.parse(widget.dateStr!)
        : DateTime.now();
    final dateLabel = widget.dateStr == null
        ? '今日复盘'
        : '${date.month}/${date.day} 复盘';

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(dateLabel),
            _buildStageTabs(),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),

            if (_flowStep >= 3 && !_reviewSaved) _buildScorePanel(),

            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),

            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String title) {
    final canSave = !_reviewSaved && _summary.isNotEmpty && !_isProcessing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('关闭'),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
          if (_existingReview != null)
            IconButton(
              tooltip: '分享',
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () => _showSnack('分享功能开发中'),
            ),
          TextButton(
            onPressed: canSave ? _saveReview : null,
            child: Text(_reviewSaved ? '已保存' : '保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildStageTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          _buildStagePill('今日总结', _flowStep <= 2),
          const SizedBox(width: 8),
          _buildStagePill('情绪能量', _flowStep == 3),
          const SizedBox(width: 8),
          _buildStagePill('AI 建议', _flowStep >= 4),
        ],
      ),
    );
  }

  Widget _buildStagePill(String label, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.primary : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: active ? Colors.white : AppColors.muted,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final align = msg.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final color = msg.isUser ? AppColors.primary : AppColors.card;
    final textColor = msg.isUser ? Colors.white : AppColors.ink;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              border: msg.isUser ? null : Border.all(color: AppColors.line),
              boxShadow: msg.isUser
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(msg.isUser ? 18 : 5),
                bottomRight: Radius.circular(msg.isUser ? 5 : 18),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildScorePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreRow(
              label: '情绪',
              value: _moodLevel,
              color: AppColors.orange,
              onChanged: (value) => setState(() => _moodLevel = value),
            ),
            const SizedBox(height: 12),
            _buildScoreRow(
              label: '能量',
              value: _energyLevel,
              color: AppColors.green,
              onChanged: (value) => setState(() => _energyLevel = value),
            ),
            if (_flowStep == 3) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _handleTextMessage('确认'),
                  child: const Text('确认评分'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label (1-5)',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final score = index + 1;
            final selected = value == score;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(score),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? color : AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected ? color : AppColors.line,
                      ),
                    ),
                    child: Text(
                      '$score',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppColors.red : AppColors.muted,
            ),
            onPressed: _isListening ? _stopListening : _startListening,
          ),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(
                hintText: _isListening ? '$_lastWords...' : '输入你想说的...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.send,
              maxLength: _maxTextInputLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxTextInputLength),
              ],
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    maxLength,
                    required isFocused,
                  }) => isFocused
                  ? Text(
                      '$currentLength/$maxLength',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    )
                  : null,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty && !_isProcessing) {
                  _handleTextMessage(text);
                  _msgCtrl.clear();
                }
              },
              enabled: !_isProcessing,
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _msgCtrl,
            builder: (context, value, _) {
              final enabled = value.text.trim().isNotEmpty && !_isProcessing;
              return IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: enabled ? AppColors.primary : AppColors.line,
                  foregroundColor: enabled ? Colors.white : AppColors.muted,
                ),
                icon: const Icon(Icons.arrow_upward),
                onPressed: enabled
                    ? () {
                        final text = _msgCtrl.text;
                        _handleTextMessage(text);
                        _msgCtrl.clear();
                      }
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}
