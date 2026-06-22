/// 周报详情页 — 查看/生成周报。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../../../core/ai/ai_provider.dart';
import '../../../../core/ai/ai_service.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/review_providers.dart';

class WeeklyReportPage extends ConsumerStatefulWidget {
  final int? year;
  final int weekNumber;

  const WeeklyReportPage({super.key, this.year, required this.weekNumber});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  late final TextEditingController _overviewCtrl;
  late final TextEditingController _highlightsCtrl;
  late final TextEditingController _improvementsCtrl;
  late final TextEditingController _planCtrl;

  bool _isLoaded = false;
  bool _isGenerating = false;
  bool _isSaving = false;
  WeeklyReportEntity? _existingReport;
  List<DailyReviewEntity> _weekReviews = const [];

  int get _reportYear => widget.year ?? ref.read(currentIsoWeekProvider).year;
  int get _reportKey => _reportYear * 100 + widget.weekNumber;

  bool get _hasReportContent =>
      _overviewCtrl.text.trim().isNotEmpty ||
      _highlightsCtrl.text.trim().isNotEmpty ||
      _improvementsCtrl.text.trim().isNotEmpty ||
      _planCtrl.text.trim().isNotEmpty;

  int get _completedTasks => _weekReviews.fold<int>(
    0,
    (sum, review) => sum + review.completedTodoIds.length,
  );

  int get _totalPattingMinutes =>
      _weekReviews.fold<int>(0, (sum, review) => sum + review.pattingMinutes);

  double get _avgMood {
    if (_weekReviews.isEmpty) return 0;
    return _weekReviews.fold<int>(0, (sum, review) => sum + review.moodLevel) /
        _weekReviews.length;
  }

  @override
  void initState() {
    super.initState();
    _overviewCtrl = TextEditingController();
    _highlightsCtrl = TextEditingController();
    _improvementsCtrl = TextEditingController();
    _planCtrl = TextEditingController();
    _loadExisting();
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
    try {
      final repo = await ref.read(reviewRepositoryProvider.future);
      final existing = await repo.getWeekly(_reportYear, widget.weekNumber);
      final weekReviews = await repo.getDailyByWeek(
        _reportYear,
        widget.weekNumber,
      );

      if (!mounted) return;
      setState(() {
        _existingReport = existing;
        _weekReviews = weekReviews;
        if (existing != null) {
          _overviewCtrl.text = existing.overview;
          _highlightsCtrl.text = existing.highlights;
          _improvementsCtrl.text = existing.improvements;
          _planCtrl.text = existing.nextWeekPlan;
        }
        _isLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoaded = true);
      _showSnack('加载周报失败: $e');
    }
  }

  Future<void> _generateWeeklyReport() async {
    setState(() => _isGenerating = true);
    try {
      final reviewRepo = await ref.read(reviewRepositoryProvider.future);
      final weekReviews = await reviewRepo.getDailyByWeek(
        _reportYear,
        widget.weekNumber,
      );

      if (weekReviews.isEmpty) {
        if (mounted) _showSnack('本周暂无日报数据，请先填写每日复盘');
        return;
      }

      if (mounted) {
        setState(() => _weekReviews = weekReviews);
      }

      final summaries = weekReviews.map((review) {
        return DailyReviewSummary(
          date: '${review.date.month}/${review.date.day}',
          summary: review.summary,
          highlights: review.highlights,
          improvements: review.improvements,
          energyLevel: review.energyLevel,
          moodLevel: review.moodLevel,
          completedCount: review.completedTodoIds.length,
          pattingMinutes: review.pattingMinutes,
        );
      }).toList();

      final ai = ref.read(aiServiceProvider);
      if (ai == null) {
        if (mounted) _showSnack('请先在设置中配置 AI API Key');
        return;
      }

      final result = await ai.generateWeeklyReport(
        weekNumber: widget.weekNumber,
        year: _reportYear,
        weekReviews: summaries,
      );

      if (!mounted) return;
      setState(() {
        _overviewCtrl.text = result.overview;
        _highlightsCtrl.text = result.highlights;
        _improvementsCtrl.text = result.improvements;
        _planCtrl.text = result.nextWeekPlan;
      });
    } catch (e) {
      if (mounted) _showSnack('生成失败: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _save() async {
    if (!_hasReportContent) {
      _showSnack('请先生成或填写周报内容');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = await ref.read(reviewRepositoryProvider.future);
      final now = DateTime.now();
      final report = WeeklyReportEntity(
        id: _existingReport?.id,
        weekNumber: widget.weekNumber,
        year: _reportYear,
        overview: _overviewCtrl.text.trim(),
        highlights: _highlightsCtrl.text.trim(),
        improvements: _improvementsCtrl.text.trim(),
        nextWeekPlan: _planCtrl.text.trim(),
        isAiGenerated: true,
        isManuallyEdited: true,
        createdAt: _existingReport?.createdAt ?? now,
        updatedAt: now,
      );

      final saved = _existingReport?.id == null
          ? await repo.createWeekly(report)
          : await repo.updateWeekly(report);

      ref.invalidate(weeklyReportByYearWeekProvider(_reportKey));
      ref.invalidate(weeklyListByYearProvider);

      if (!mounted) return;
      setState(() => _existingReport = saved);
      _showSnack('周报已保存');
    } catch (e) {
      if (mounted) _showSnack('保存失败: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareReport() async {
    if (!_hasReportContent) {
      _showSnack('请先生成或填写周报内容');
      return;
    }

    try {
      await SharePlus.instance.share(ShareParams(text: _buildShareText()));
    } catch (e) {
      if (mounted) _showSnack('分享失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoaded
                  ? _buildContent()
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => context.pop(),
            icon: const Icon(Icons.chevron_left),
            label: const Text('返回'),
          ),
          Expanded(
            child: Text(
              '第 ${widget.weekNumber} 周周报',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
          TextButton(onPressed: _shareReport, child: const Text('分享')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        _buildOverviewCard(),
        const SizedBox(height: 16),
        _buildMetricsGrid(),
        const SizedBox(height: 22),
        _buildEditableSection(
          title: '本周亮点',
          icon: Icons.auto_awesome_outlined,
          color: AppColors.gold,
          controller: _highlightsCtrl,
          hintText: '记录这一周做得好的事...',
        ),
        const SizedBox(height: 16),
        _buildEditableSection(
          title: '待改进',
          icon: Icons.trending_up,
          color: AppColors.orange,
          controller: _improvementsCtrl,
          hintText: '记录可以优化的节奏、习惯或风险...',
        ),
        const SizedBox(height: 16),
        _buildEditableSection(
          title: '下周计划',
          icon: Icons.flag_outlined,
          color: AppColors.green,
          controller: _planCtrl,
          hintText: '写下下周最重要的行动...',
        ),
        const SizedBox(height: 24),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.blue, Color(0xFF365D8B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _heroTitle(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'AI 综合分析评语 · $_reportYear 年',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _overviewCtrl,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.white,
            ),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: '生成后这里会显示本周概览，也可以手动填写。',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppMetricCard(
                label: '完成任务',
                value: '$_completedTasks 项',
                color: AppColors.ink,
                icon: Icons.task_alt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppMetricCard(
                label: '总盘玩',
                value: '${_totalPattingMinutes}m',
                color: AppColors.primary,
                icon: Icons.diamond_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppMetricCard(
                label: '平均情绪',
                value: _avgMood == 0 ? '-' : _avgMood.toStringAsFixed(1),
                color: AppColors.orange,
                icon: Icons.face_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppMetricCard(
                label: '复盘天数',
                value: '${_weekReviews.length} 天',
                color: AppColors.green,
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditableSection({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(
          title: title,
          padding: EdgeInsets.zero,
          trailing: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 10),
        AppSurfaceCard(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(color: AppColors.muted),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isGenerating ? null : _generateWeeklyReport,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isGenerating ? '生成中...' : '重新生成周报'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? '保存中...' : '保存周报'),
          ),
        ),
      ],
    );
  }

  String _heroTitle() {
    if (!_hasReportContent) return '等待生成周报';
    if (_avgMood >= 4) return '状态向上的一周';
    if (_avgMood > 0 && _avgMood < 3) return '蓄力调整的一周';
    return '稳步前行的一周';
  }

  String _buildShareText() {
    final lines = <String>[
      '$_reportYear 年第 ${widget.weekNumber} 周周报',
      '完成任务：$_completedTasks 项',
      '总盘玩：$_totalPattingMinutes 分钟',
      '平均情绪：${_avgMood == 0 ? '-' : _avgMood.toStringAsFixed(1)}',
      '复盘天数：${_weekReviews.length} 天',
    ];

    void addSection(String title, String content) {
      final text = content.trim();
      if (text.isEmpty) return;
      lines
        ..add('')
        ..add('$title：')
        ..add(text);
    }

    addSection('本周概览', _overviewCtrl.text);
    addSection('本周亮点', _highlightsCtrl.text);
    addSection('待改进', _improvementsCtrl.text);
    addSection('下周计划', _planCtrl.text);

    return lines.join('\n');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
