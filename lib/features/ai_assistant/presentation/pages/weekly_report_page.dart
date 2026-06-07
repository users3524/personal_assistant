/// 周报详情页 — 查看/生成周报。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_service.dart';
import '../../../../core/ai/ai_provider.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/review_providers.dart';

class WeeklyReportPage extends ConsumerStatefulWidget {
  final int weekNumber;

  const WeeklyReportPage({super.key, required this.weekNumber});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  bool _isGenerating = false;
  late TextEditingController _overviewCtrl;
  late TextEditingController _highlightsCtrl;
  late TextEditingController _improvementsCtrl;
  late TextEditingController _planCtrl;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _overviewCtrl = TextEditingController();
    _highlightsCtrl = TextEditingController();
    _improvementsCtrl = TextEditingController();
    _planCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _overviewCtrl.dispose();
    _highlightsCtrl.dispose();
    _improvementsCtrl.dispose();
    _planCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_isLoaded) return;
    final repo = await ref.read(reviewRepositoryProvider.future);
    final existing = await repo.getWeekly(
      DateTime.now().year,
      widget.weekNumber,
    );
    if (existing != null && mounted) {
      setState(() {
        _overviewCtrl.text = existing.overview;
        _highlightsCtrl.text = existing.highlights;
        _improvementsCtrl.text = existing.improvements;
        _planCtrl.text = existing.nextWeekPlan;
        _isLoaded = true;
      });
    } else {
      _isLoaded = true;
    }
  }

  Future<void> _generateWeeklyReport() async {
    setState(() => _isGenerating = true);
    try {
      final reviewRepo = await ref.read(reviewRepositoryProvider.future);
      final now = DateTime.now();

      // 获取本周日报
      final weekReviews =
          await reviewRepo.getDailyByWeek(now.year, widget.weekNumber);

      if (weekReviews.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('本周暂无日报数据，请先填写每日复盘')),
          );
        }
        return;
      }

      // 构建精简摘要
      final summaries = weekReviews.map((r) {
        return DailyReviewSummary(
          date: '${r.date.month}/${r.date.day}',
          summary: r.summary,
          highlights: r.highlights,
          improvements: r.improvements,
          energyLevel: r.energyLevel,
          moodLevel: r.moodLevel,
          completedCount: r.completedTodoIds.length,
          pattingMinutes: r.pattingMinutes,
        );
      }).toList();

      // 调用 AI
      final ai = ref.read(aiServiceProvider);
      if (ai == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先在设置中配置 AI API Key')),
          );
        }
        setState(() => _isGenerating = false);
        return;
      }

      final result = await ai.generateWeeklyReport(
        weekNumber: widget.weekNumber,
        year: now.year,
        weekReviews: summaries,
      );

      if (mounted) {
        setState(() {
          _overviewCtrl.text = result.overview;
          _highlightsCtrl.text = result.highlights;
          _improvementsCtrl.text = result.improvements;
          _planCtrl.text = result.nextWeekPlan;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _save() async {
    try {
      final repo = await ref.read(reviewRepositoryProvider.future);
      final now = DateTime.now();
      final report = WeeklyReportEntity(
        weekNumber: widget.weekNumber,
        year: now.year,
        overview: _overviewCtrl.text.trim(),
        highlights: _highlightsCtrl.text.trim(),
        improvements: _improvementsCtrl.text.trim(),
        nextWeekPlan: _planCtrl.text.trim(),
        isAiGenerated: true,
        isManuallyEdited: true,
        createdAt: now,
        updatedAt: now,
      );
      await repo.createWeekly(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('周报已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();

    return Scaffold(
      appBar: AppBar(
        title: Text('第 ${widget.weekNumber} 周周报'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI 生成按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _generateWeeklyReport,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                    _isGenerating ? 'AI 生成中...' : 'AI 生成周报'),
              ),
            ),
            const SizedBox(height: 24),

            // 本周概览
            Text('本周概览',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _overviewCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '本周的整体表现...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 本周亮点
            Text('本周亮点',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _highlightsCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '用 • 开头列出亮点...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 待改进
            Text('待改进',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _improvementsCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '用 • 开头列出改进项...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 下周计划
            Text('下周计划',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _planCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '用 • 开头列出计划...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
