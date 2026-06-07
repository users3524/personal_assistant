/// 复盘对话页 — 对话问答式日复盘。
///
/// 用户通过文字或语音输入每天的总结和感受，
/// AI 以对话方式引导复盘，最终生成结构化日报并保存。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/ai/ai_provider.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review_entity.dart';
import '../../../todo/presentation/providers/todo_providers.dart';

// ===== 对话消息模型 =====

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();
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
  String _sentimentTag = '平稳';

  // 语音识别
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

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
        _messages.add(ChatMessage(
          text: '📋 以下是 ${date.month}/${date.day} 的已有复盘记录',
          isUser: false,
        ));
        _messages.add(ChatMessage(text: '总结：$_summary', isUser: false));
        if (_highlights.isNotEmpty) {
          _messages.add(ChatMessage(text: '收获：$_highlights', isUser: false));
        }
        if (_improvements.isNotEmpty) {
          _messages.add(ChatMessage(text: '不足：$_improvements', isUser: false));
        }
        _messages.add(ChatMessage(
          text: '✨ AI 评语：$_aiComment',
          isUser: false,
        ));
        _messages.add(ChatMessage(
          text: '💡 AI 建议：$_aiSuggestion',
          isUser: false,
        ));
        if (_aiComment.isNotEmpty) _reviewSaved = true;
      });
    }
  }

  void _addWelcomeMessage() {
    if (widget.dateStr != null && _existingReview != null) return;
    _messages.add(ChatMessage(
      text: '👋 今天过得怎么样？跟我说说今天的经历和感受吧！\n\n'
          '你可以输入文字或点击麦克风语音输入。',
      isUser: false,
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isProcessing = true;
    });
    _scrollToBottom();

    // 第一步：先收集用户输入作为总结
    if (_summary.isEmpty) {
      setState(() {
        _summary = text.trim();
        // 询问更多信息
        _messages.add(ChatMessage(
          text: '好的，收到了！今天有什么特别开心的收获或成就吗？🥰',
          isUser: false,
        ));
        _isProcessing = false;
      });
      return;
    }

    // 第二步：收集收获
    if (_highlights.isEmpty) {
      setState(() {
        _highlights = text.trim();
        _messages.add(ChatMessage(
          text: '真棒！那有什么不足或想改进的地方吗？🤔',
          isUser: false,
        ));
        _isProcessing = false;
      });
      return;
    }

    // 第三步：收集不足
    if (_improvements.isEmpty) {
      setState(() {
        _improvements = text.trim();
        _messages.add(ChatMessage(
          text: '感谢分享！现在给你的今天打个分吧：',
          isUser: false,
        ));
        _messages.add(_buildMoodEnergySelector());
        _isProcessing = false;
      });
      return;
    }

    // 第四步：已有所有信息 → 调用 AI 生成复盘
    await _generateReview();
  }

  ChatMessage _buildMoodEnergySelector() {
    return ChatMessage(
      text: '请选择情绪和能量水平（1-5）：\n\n'
          '当前设置 — 情绪：$_moodLevel ⭐  能量：$_energyLevel ⚡\n'
          '回复「确认」或修改数值如「情绪4 能量5」',
      isUser: false,
    );
  }

  Future<void> _generateReview() async {
    final ai = ref.read(aiServiceProvider);
    if (ai == null) {
      setState(() {
        _messages.add(ChatMessage(
          text: '⚠️ 请先在设置中配置 AI API Key 后使用 AI 生成功能。\n'
              '（或者你也可以直接手动填写保存）',
          isUser: false,
        ));
        _isProcessing = false;
      });
      return;
    }

    try {
      // 获取今日已完成待办
      final repo = await ref.read(todoRepositoryProvider.future);
      final todayTodos = await repo.getToday();
      final completedTitles = todayTodos
          .where((t) => t.isDone)
          .map((t) => t.title)
          .toList();

      // 调用 AI
      final result = await ai.generateDailyReview(
        summary: _summary,
        highlights: _highlights,
        improvements: _improvements,
        energyLevel: _energyLevel,
        moodLevel: _moodLevel,
        completedTitles: completedTitles,
        pattingMinutes: 0,
      );

      setState(() {
        _aiComment = result.comment;
        _aiSuggestion = result.suggestion;
        _sentimentTag = result.sentimentTag;
        _messages.add(ChatMessage(
          text: '✨ **AI 复盘**\n\n'
              '📝 ${result.comment}\n\n'
              '💡 建议：${result.suggestion}\n\n'
              '🏷️ 情绪标签：${result.sentimentTag}',
          isUser: false,
        ));
        _messages.add(ChatMessage(
          text: '以上是 AI 为你生成的复盘。要保存吗？\n'
              '回复「确认」或「保存」✅',
          isUser: false,
        ));
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: '❌ AI 生成失败：$e\n\n'
              '你可以手动填写后保存。',
          isUser: false,
        ));
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveReview() async {
    if (_reviewSaved) {
      _showSnack('已保存');
      return;
    }

    try {
      final repo = await ref.read(reviewRepositoryProvider.future);

      if (_existingReview != null) {
        // 更新
        await repo.updateDaily(_existingReview!.copyWith(
          summary: _summary,
          highlights: _highlights.isNotEmpty ? _highlights : null,
          improvements: _improvements.isNotEmpty ? _improvements : null,
          energyLevel: _energyLevel,
          moodLevel: _moodLevel,
          aiComment: _aiComment.isNotEmpty ? _aiComment : null,
          aiSuggestion: _aiSuggestion.isNotEmpty ? _aiSuggestion : null,
        ));
      } else {
        // 新建
        final now = DateTime.now();
        final date = widget.dateStr != null
            ? DateTime.parse(widget.dateStr!)
            : DateTime(now.year, now.month, now.day);
        await repo.createDaily(DailyReviewEntity(
          date: date,
          summary: _summary,
          highlights: _highlights.isNotEmpty ? _highlights : null,
          improvements: _improvements.isNotEmpty ? _improvements : null,
          energyLevel: _energyLevel,
          moodLevel: _moodLevel,
          aiComment: _aiComment.isNotEmpty ? _aiComment : null,
          aiSuggestion: _aiSuggestion.isNotEmpty ? _aiSuggestion : null,
          isAiGenerated: _aiComment.isNotEmpty,
          isManuallyEdited: _aiComment.isEmpty,
          createdAt: now,
          updatedAt: now,
        ));
      }

      setState(() => _reviewSaved = true);
      _messages.add(ChatMessage(
        text: '✅ 复盘已保存！',
        isUser: false,
      ));

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
      localeId: 'zh_CN',
    );
  }

  void _stopListening() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _setMoodEnergy(String text) {
    final moodMatch = RegExp(r'情绪[：:\s]*(\d)').firstMatch(text);
    final energyMatch = RegExp(r'能量[：:\s]*(\d)').firstMatch(text);
    final confirmMatch = RegExp(r'确认|确定|好|可以').hasMatch(text);

    if (confirmMatch && moodMatch == null && energyMatch == null) {
      // 确认当前值
      setState(() {
        _messages.add(ChatMessage(
          text: '好的，情绪：$_moodLevel ⭐  能量：$_energyLevel ⚡',
          isUser: false,
        ));
        _isProcessing = true;
      });
      _generateReview();
      return;
    }

    if (moodMatch != null) {
      _moodLevel = int.parse(moodMatch.group(1)!);
    }
    if (energyMatch != null) {
      _energyLevel = int.parse(energyMatch.group(1)!);
    }
    setState(() {
      _messages.add(ChatMessage(
        text: '情绪：$_moodLevel ⭐  能量：$_energyLevel ⚡',
        isUser: false,
      ));
      _isProcessing = true;
    });
    _generateReview();
  }

  void _handleTextMessage(String text) {
    final lower = text.trim().toLowerCase();

    // 保存确认
    if (_reviewSaved == false &&
        _aiComment.isNotEmpty &&
        (lower.contains('确认') || lower.contains('保存') || lower.contains('好'))) {
      _saveReview();
      return;
    }

    // 情绪/能量设置
    if (_summary.isNotEmpty && _highlights.isNotEmpty && _improvements.isNotEmpty) {
      if (RegExp(r'情绪|能量|确认|好|可以').hasMatch(lower) && _aiComment.isEmpty) {
        _setMoodEnergy(text);
        return;
      }
    }

    _sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.dateStr != null
        ? DateTime.parse(widget.dateStr!)
        : DateTime.now();
    final dateLabel = '${date.month}/${date.day} 复盘';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(dateLabel),
        actions: [
          if (_reviewSaved || _existingReview != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // 跳转到编辑模式（传统表单）
                _showSnack('在聊天中直接修改即可');
              },
            ),
          if (_existingReview != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _showSnack('分享功能开发中'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // 处理中指示器
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          // 输入栏
          _buildInputBar(),
        ],
      ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final align = msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = msg.isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = msg.isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                bottomRight: Radius.circular(msg.isUser ? 4 : 20),
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
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 语音按钮
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : Colors.grey,
            ),
            onPressed: _isListening ? _stopListening : _startListening,
          ),
          // 文本输入
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(
                hintText: _isListening
                    ? '${_lastWords}...'
                    : '说说今天的经历...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty && !_isProcessing) {
                  _handleTextMessage(text);
                  _msgCtrl.clear();
                }
              },
              enabled: !_isProcessing,
            ),
          ),
          const SizedBox(width: 4),
          // 发送按钮
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: _msgCtrl.text.isNotEmpty && !_isProcessing
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            onPressed: () {
              final text = _msgCtrl.text;
              if (text.trim().isNotEmpty && !_isProcessing) {
                _handleTextMessage(text);
                _msgCtrl.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}
