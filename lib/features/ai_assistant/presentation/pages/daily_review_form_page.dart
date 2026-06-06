/// 每日复盘填写页 — 含 AI 生成功能。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ai/ai_service.dart';
import '../../../../core/ai/openai_service.dart';
import '../../../todo/domain/entities/todo_entity.dart';
import '../../../todo/presentation/providers/todo_providers.dart';
import '../../../collection/presentation/providers/antique_providers.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/review_providers.dart';

class DailyReviewFormPage extends ConsumerStatefulWidget {
  const DailyReviewFormPage({super.key});

  @override
  ConsumerState<DailyReviewFormPage> createState() =>
      _DailyReviewFormPageState();
}

class _DailyReviewFormPageState extends ConsumerState<DailyReviewFormPage> {
  final _summaryCtrl = TextEditingController();
  final _highlightsCtrl = TextEditingController();
  final _improvementsCtrl = TextEditingController();

  int _energyLevel = 3;
  int _moodLevel = 3;
  bool _isGenerating = false;
  bool _isSaving = false;

  // AI 生成结果
  String? _aiComment;
  String? _aiSuggestion;
  String _sentimentTag = '';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final repo = await ref.read(reviewRepositoryProvider.future);
    final existing = await repo.getDailyByDate(DateTime.now());
    if (existing != null && mounted) {
      setState(() {
        _summaryCtrl.text = existing.summary;
        _highlightsCtrl.text = existing.highlights ?? '';
        _improvementsCtrl.text = existing.improvements ?? '';
        _energyLevel = existing.energyLevel;
        _moodLevel = existing.moodLevel;
        _aiComment = existing.aiComment;
        _aiSuggestion = existing.aiSuggestion;
      });
    }
  }

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _highlightsCtrl.dispose();
    _improvementsCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAIReview() async {
    if (_summaryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写今日总结')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // 获取今日完成的待办标题
      final todoRepo = await ref.read(todoRepositoryProvider.future);
      final completedTodos = await todoRepo.getByStatus(TodoStatus.done);

      // 获取今日盘玩时长
      final antiqueRepo =
          await ref.read(antiqueRepositoryProvider.future);
      final pattingLogs = await antiqueRepo.getPattingLogsByDate(DateTime.now());
      final totalPattingMinutes =
          pattingLogs.fold(0, (sum, log) => sum + log.durationMinutes);

      // 调用 AI
      final ai = OpenAIService(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: '', // 需要用户配置
      );

      final result = await ai.generateDailyReview(
        summary: _summaryCtrl.text.trim(),
        highlights: _highlightsCtrl.text.trim().isEmpty
            ? null
            : _highlightsCtrl.text.trim(),
        improvements: _improvementsCtrl.text.trim().isEmpty
            ? null
            : _improvementsCtrl.text.trim(),
        energyLevel: _energyLevel,
        moodLevel: _moodLevel,
        completedTitles: completedTodos.map((t) => t.title).toList(),
        pattingMinutes: totalPattingMinutes,
      );

      if (mounted) {
        setState(() {
          _aiComment = result.comment;
          _aiSuggestion = result.suggestion;
          _sentimentTag = result.sentimentTag;
        });
      }
    } catch (e) {
      if (mounted) {
        // AI 调用失败时使用本地兜底
        setState(() {
          _aiComment = _generateLocalComment();
          _aiSuggestion = _generateLocalSuggestion();
          _sentimentTag = _energyLevel >= 4 ? '高效' : '平稳';
        });
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _generateLocalComment() {
    if (_energyLevel >= 4 && _moodLevel >= 4) {
      return '今天状态非常好，能量和情绪都在高位，继续保持！';
    } else if (_energyLevel <= 2) {
      return '今天看起来有些疲惫，注意休息和调整节奏。';
    }
    return '平稳度过的一天，有收获也有成长空间。';
  }

  String _generateLocalSuggestion() {
    if (_summaryCtrl.text.contains('工作') || _summaryCtrl.text.contains('项目')) {
      return '建议明天优先处理最重要的一件事，减少多任务切换。';
    }
    return '尝试每天留出 15 分钟给自己，放松心情。';
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = await ref.read(reviewRepositoryProvider.future);

      // 获取今日完成的待办 ID 列表
      final todoRepo = await ref.read(todoRepositoryProvider.future);
      final completedTodos = await todoRepo.getByStatus(TodoStatus.done);

      // 获取今日盘玩时长
      final antiqueRepo =
          await ref.read(antiqueRepositoryProvider.future);
      final pattingLogs = await antiqueRepo.getPattingLogsByDate(DateTime.now());
      final totalPattingMinutes =
          pattingLogs.fold(0, (sum, log) => sum + log.durationMinutes);

      final now = DateTime.now();
      final review = DailyReviewEntity(
        date: now,
        summary: _summaryCtrl.text.trim(),
        highlights: _highlightsCtrl.text.trim().isEmpty
            ? null
            : _highlightsCtrl.text.trim(),
        improvements: _improvementsCtrl.text.trim().isEmpty
            ? null
            : _improvementsCtrl.text.trim(),
        energyLevel: _energyLevel,
        moodLevel: _moodLevel,
        completedTodoIds: completedTodos.map((t) => t.id!).toList(),
        pattingMinutes: totalPattingMinutes,
        aiComment: _aiComment,
        aiSuggestion: _aiSuggestion,
        isAiGenerated: _aiComment != null,
        isManuallyEdited: _aiComment != null && _aiSuggestion != null,
        createdAt: now,
        updatedAt: now,
      );

      await repo.createDaily(review);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日复盘已保存')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('每日复盘'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期
            Center(
              child: Text(
                '${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 24),

            // 今日总结
            Text('今日总结', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _summaryCtrl,
              decoration: const InputDecoration(
                hintText: '今天做了什么？有什么收获？',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // 今日收获
            Text('今日收获（可选）',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _highlightsCtrl,
              decoration: const InputDecoration(
                hintText: '今天有哪些值得开心的事？',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // 今日不足
            Text('今日不足（可选）',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _improvementsCtrl,
              decoration: const InputDecoration(
                hintText: '有什么需要改进的地方？',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // 情绪 + 能量选择
            Row(
              children: [
                Expanded(child: _buildLevelSelector(
                  label: '情绪',
                  emojis: ['😞', '😐', '🙂', '😊', '😄'],
                  level: _moodLevel,
                  onChanged: (v) => setState(() => _moodLevel = v),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildLevelSelector(
                  label: '能量',
                  emojis: ['🪫', '🔋', '⚡', '⚡⚡', '⚡⚡⚡'],
                  level: _energyLevel,
                  onChanged: (v) => setState(() => _energyLevel = v),
                )),
              ],
            ),
            const SizedBox(height: 24),

            // AI 生成按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generateAIReview,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                    _isGenerating ? 'AI 思考中...' : 'AI 生成复盘评语'),
              ),
            ),
            const SizedBox(height: 20),

            // AI 结果展示
            if (_aiComment != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 18),
                          const SizedBox(width: 8),
                          Text('AI 评语',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall),
                          const Spacer(),
                          if (_sentimentTag.isNotEmpty)
                            Chip(
                              label: Text(_sentimentTag,
                                  style: const TextStyle(fontSize: 11)),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_aiComment!),
                      if (_aiSuggestion != null) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 4),
                        Text('💡 建议',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall),
                        const SizedBox(height: 4),
                        Text(_aiSuggestion!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _generateAIReview,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重新生成'),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSelector({
    required String label,
    required List<String> emojis,
    required int level,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(emojis.length, (index) {
            final value = index + 1;
            final selected = value == level;
            return GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(emojis[index], style: const TextStyle(fontSize: 20)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
