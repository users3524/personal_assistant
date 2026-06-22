/// 简历首页 — 默认预览模式，点击编辑进入长条滑动编辑页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/app_chrome.dart';
import '../../domain/entities/resume_entity.dart';
import '../providers/resume_providers.dart';
import '../services/resume_png_export_service.dart';
import '../widgets/resume_templates.dart';

class ResumeHomePage extends ConsumerStatefulWidget {
  const ResumeHomePage({super.key});

  @override
  ConsumerState<ResumeHomePage> createState() => _ResumeHomePageState();
}

class _ResumeHomePageState extends ConsumerState<ResumeHomePage> {
  final _repaintKey = GlobalKey();
  final _pngExportService = ResumePngExportService();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(resumeDataProvider);
    final templateId = ref.watch(selectedTemplateIdProvider).valueOrNull ?? 0;

    return Scaffold(
      body: SafeArea(
        child: dataAsync.when(
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 88),
            children: [
              AppPageHeader(
                title: '简历',
                subtitle: '预览、编辑并导出你的动态履历',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: '设置',
                      onPressed: () => context.push('/settings'),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.edit),
                      tooltip: '编辑简历',
                      onPressed: _openEditor,
                    ),
                    IconButton(
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_outlined),
                      tooltip: '导出分享',
                      onPressed: _isExporting ? null : _exportAsImage,
                    ),
                    _buildTemplateMenu(),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.profile.fullName.isEmpty
                                ? '未填写姓名'
                                : data.profile.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            data.profile.jobTitle ?? '点击编辑完善职位头衔',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppPill(
                      label: _templateName(templateId),
                      color: AppColors.primary,
                      icon: Icons.design_services_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppSurfaceCard(
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: Container(
                        width: 360, // A4 比例约束
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildTemplate(data, templateId),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('加载失败: $err')),
        ),
      ),
    );
  }

  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ResumeEditPage()),
    );
  }

  Widget _buildTemplateMenu() {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.design_services),
      tooltip: '切换模板',
      onSelected: (id) =>
          ref.read(selectedTemplateIdProvider.notifier).select(id),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 0,
          child: ListTile(
            leading: Icon(Icons.article),
            title: Text('简洁经典'),
            subtitle: Text('单栏布局，适合传统行业'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 1,
          child: ListTile(
            leading: Icon(Icons.credit_card),
            title: Text('现代卡片'),
            subtitle: Text('双栏布局，适合设计/产品岗'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 2,
          child: ListTile(
            leading: Icon(Icons.code),
            title: Text('技术极简'),
            subtitle: Text('等宽字体，适合程序员'),
            dense: true,
          ),
        ),
      ],
    );
  }

  String _templateName(int templateId) {
    switch (templateId) {
      case 1:
        return '现代卡片';
      case 2:
        return '技术极简';
      default:
        return '简洁经典';
    }
  }

  Widget _buildTemplate(ResumeData data, int templateId) {
    switch (templateId) {
      case 1:
        return ModernResumeTemplate(data);
      case 2:
        return TechResumeTemplate(data);
      default:
        return ClassicResumeTemplate(data);
    }
  }

  Future<void> _exportAsImage() async {
    setState(() => _isExporting = true);
    try {
      final file = await _pngExportService.export(_repaintKey);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              '个人简历 - ${ref.read(resumeDataProvider).valueOrNull?.profile.fullName ?? ""}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// ===== 长条滑动编辑页 =====

class _ResumeEditPage extends ConsumerStatefulWidget {
  const _ResumeEditPage();

  @override
  ConsumerState<_ResumeEditPage> createState() => _ResumeEditPageState();
}

class _ResumeEditPageState extends ConsumerState<_ResumeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _infoKey = GlobalKey();
  final _eduKey = GlobalKey();
  final _projectKey = GlobalKey();
  final _workKey = GlobalKey();
  final _skillKey = GlobalKey();

  // Profile controllers
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();

  // Work
  List<_WorkEditItem> _works = [];
  // Education
  List<_EduEditItem> _educations = [];
  // Skills
  List<_SkillEditItem> _skills = [];
  // Projects
  List<_ProjectEditItem> _projects = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = await ref.read(resumeRepositoryProvider.future);
    final profile = await repo.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _nameCtrl.text = profile.fullName;
        _titleCtrl.text = profile.jobTitle ?? '';
        _emailCtrl.text = profile.email ?? '';
        _phoneCtrl.text = profile.phone ?? '';
        _locationCtrl.text = profile.location ?? '';
        _summaryCtrl.text = profile.personalSummary ?? '';
      });
    }
    final works = await repo.getWorkExperiences();
    final educations = await repo.getEducations();
    final skills = await repo.getSkills();
    final projects = await repo.getProjects();
    if (mounted) {
      setState(() {
        _works = works
            .map(
              (w) => _WorkEditItem(
                id: w.id,
                companyCtrl: TextEditingController(text: w.company),
                positionCtrl: TextEditingController(text: w.position),
                descCtrl: TextEditingController(text: w.description ?? ''),
                techStackCtrl: TextEditingController(
                  text: w.techStack.join(', '),
                ),
                isVisible: w.isVisible,
              ),
            )
            .toList();
        _educations = educations
            .map(
              (e) => _EduEditItem(
                id: e.id,
                schoolCtrl: TextEditingController(text: e.school),
                majorCtrl: TextEditingController(text: e.major),
                degreeCtrl: TextEditingController(text: e.degree),
                isVisible: e.isVisible,
              ),
            )
            .toList();
        _skills = skills
            .map(
              (s) => _SkillEditItem(
                id: s.id,
                nameCtrl: TextEditingController(text: s.name),
                categoryCtrl: TextEditingController(text: s.category),
                proficiency: s.proficiency,
                isVisible: s.isVisible,
              ),
            )
            .toList();
        _projects = projects
            .map(
              (p) => _ProjectEditItem(
                id: p.id,
                nameCtrl: TextEditingController(text: p.name),
                roleCtrl: TextEditingController(text: p.role ?? ''),
                descCtrl: TextEditingController(text: p.description ?? ''),
                techStackCtrl: TextEditingController(
                  text: p.techStack.join(', '),
                ),
                keyDeliverablesCtrl: TextEditingController(
                  text: p.keyDeliverables.join('\n'),
                ),
                badgesCtrl: TextEditingController(text: p.badges.join(', ')),
                isVisible: p.isVisible,
              ),
            )
            .toList();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _summaryCtrl.dispose();
    for (final w in _works) {
      w.companyCtrl.dispose();
      w.positionCtrl.dispose();
      w.descCtrl.dispose();
      w.techStackCtrl.dispose();
    }
    for (final e in _educations) {
      e.schoolCtrl.dispose();
      e.majorCtrl.dispose();
      e.degreeCtrl.dispose();
    }
    for (final s in _skills) {
      s.nameCtrl.dispose();
      s.categoryCtrl.dispose();
    }
    for (final p in _projects) {
      p.nameCtrl.dispose();
      p.roleCtrl.dispose();
      p.descCtrl.dispose();
      p.techStackCtrl.dispose();
      p.keyDeliverablesCtrl.dispose();
      p.badgesCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    final repo = await ref.read(resumeRepositoryProvider.future);

    await repo.saveProfile(
      ResumeProfileEntity(
        fullName: _nameCtrl.text.trim(),
        jobTitle: _titleCtrl.text.trim().isEmpty
            ? null
            : _titleCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        personalSummary: _summaryCtrl.text.trim().isEmpty
            ? null
            : _summaryCtrl.text.trim(),
        updatedAt: DateTime.now(),
      ),
    );

    for (final w in _works) {
      await repo.saveWorkExperience(
        WorkExperienceEntity(
          id: w.id,
          company: w.companyCtrl.text.trim(),
          position: w.positionCtrl.text.trim(),
          description: w.descCtrl.text.trim().isEmpty
              ? null
              : w.descCtrl.text.trim(),
          techStack: w.techStackCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          startDate: DateTime.now(),
          isVisible: w.isVisible,
        ),
      );
    }

    for (final e in _educations) {
      await repo.saveEducation(
        EducationEntity(
          id: e.id,
          school: e.schoolCtrl.text.trim(),
          major: e.majorCtrl.text.trim(),
          degree: e.degreeCtrl.text.trim().isEmpty
              ? '本科'
              : e.degreeCtrl.text.trim(),
          startDate: DateTime.now(),
          isVisible: e.isVisible,
        ),
      );
    }

    for (final s in _skills) {
      await repo.saveSkill(
        SkillItemEntity(
          id: s.id,
          name: s.nameCtrl.text.trim(),
          category: s.categoryCtrl.text.trim().isEmpty
              ? 'tool'
              : s.categoryCtrl.text.trim(),
          proficiency: s.proficiency,
          isVisible: s.isVisible,
        ),
      );
    }

    for (final p in _projects) {
      await repo.saveProject(
        ProjectExperienceEntity(
          id: p.id,
          name: p.nameCtrl.text.trim(),
          role: p.roleCtrl.text.trim().isEmpty ? null : p.roleCtrl.text.trim(),
          description: p.descCtrl.text.trim().isEmpty
              ? null
              : p.descCtrl.text.trim(),
          techStack: p.techStackCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          keyDeliverables: _splitLines(p.keyDeliverablesCtrl.text),
          badges: _splitDelimitedList(p.badgesCtrl.text),
          startDate: DateTime.now(),
          isVisible: p.isVisible,
        ),
      );
    }

    ref.read(resumeRefreshProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('简历已保存')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildEditorTopBar(),
            if (!_isLoading) _buildSectionNav(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildEditorContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.primary,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left),
            label: const Text('返回'),
          ),
          const Expanded(
            child: Text(
              '编辑简历',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _saveAll,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionNav() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildNavPill('个人信息', _infoKey, true),
          _buildNavPill('教育/技能', _eduKey, false),
          _buildNavPill('项目经历', _projectKey, false),
          _buildNavPill('工作经历', _workKey, false),
        ],
      ),
    );
  }

  Widget _buildNavPill(String label, GlobalKey targetKey, bool active) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _scrollTo(targetKey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  void _scrollTo(GlobalKey targetKey) {
    final targetContext = targetKey.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  Widget _buildEditorContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPersonalSection(),
            const SizedBox(height: 22),
            _buildEducationAndSkillsSection(),
            const SizedBox(height: 22),
            _buildProjectsSection(),
            const SizedBox(height: 22),
            _buildWorksSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalSection() {
    return _buildEditorSection(
      key: _infoKey,
      title: '个人信息',
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: _fieldDecoration('姓名 *'),
              validator: (v) => v == null || v.trim().isEmpty ? '姓名不能为空' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: _fieldDecoration('职位头衔'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: _fieldDecoration('邮箱'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: _fieldDecoration('手机号'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: _fieldDecoration('所在地'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryCtrl,
              decoration: _fieldDecoration('个人简介', hintText: '简短介绍自己...'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationAndSkillsSection() {
    return _buildEditorSection(
      key: _eduKey,
      title: '教育与技能',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _educations.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _educations.removeAt(oldIndex);
                _educations.insert(newIndex, item);
              });
            },
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) => ReorderableDragStartListener(
              key: ValueKey('edu_$index'),
              index: index,
              child: _buildEduCard(index, _educations[index]),
            ),
          ),
          _buildAddButton(
            label: '添加教育经历',
            onPressed: () {
              setState(
                () => _educations.add(
                  _EduEditItem(
                    schoolCtrl: TextEditingController(),
                    majorCtrl: TextEditingController(),
                    degreeCtrl: TextEditingController(text: '本科'),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _skillKey,
            child: const AppSectionTitle(title: '技能', padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _skills.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _skills.removeAt(oldIndex);
                _skills.insert(newIndex, item);
              });
            },
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) => ReorderableDragStartListener(
              key: ValueKey('skill_$index'),
              index: index,
              child: _buildSkillCard(index, _skills[index]),
            ),
          ),
          _buildAddButton(
            label: '添加技能',
            onPressed: () {
              setState(
                () => _skills.add(
                  _SkillEditItem(
                    nameCtrl: TextEditingController(),
                    categoryCtrl: TextEditingController(text: 'tool'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsSection() {
    return _buildEditorSection(
      key: _projectKey,
      title: '项目经历',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _projects.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _projects.removeAt(oldIndex);
                _projects.insert(newIndex, item);
              });
            },
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) => ReorderableDragStartListener(
              key: ValueKey('proj_$index'),
              index: index,
              child: _buildProjectCard(index, _projects[index]),
            ),
          ),
          _buildAddButton(
            label: '添加项目经历',
            onPressed: () {
              setState(
                () => _projects.add(
                  _ProjectEditItem(
                    nameCtrl: TextEditingController(),
                    roleCtrl: TextEditingController(),
                    descCtrl: TextEditingController(),
                    techStackCtrl: TextEditingController(),
                    keyDeliverablesCtrl: TextEditingController(),
                    badgesCtrl: TextEditingController(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorksSection() {
    return _buildEditorSection(
      key: _workKey,
      title: '工作经历',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _works.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _works.removeAt(oldIndex);
                _works.insert(newIndex, item);
              });
            },
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) => ReorderableDragStartListener(
              key: ValueKey('work_$index'),
              index: index,
              child: _buildWorkCard(index, _works[index]),
            ),
          ),
          _buildAddButton(
            label: '添加工作经历',
            onPressed: () {
              setState(
                () => _works.add(
                  _WorkEditItem(
                    companyCtrl: TextEditingController(),
                    positionCtrl: TextEditingController(),
                    descCtrl: TextEditingController(),
                    techStackCtrl: TextEditingController(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEditorSection({
    required GlobalKey key,
    required String title,
    required Widget child,
  }) {
    return KeyedSubtree(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionTitle(title: title, padding: EdgeInsets.zero),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
    );
  }

  InputDecoration _fieldDecoration(String label, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  Widget _buildWorkCard(int index, _WorkEditItem item) {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '工作 ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Switch(
                value: item.isVisible,
                onChanged: (v) => setState(() => item.isVisible = v),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.red,
                ),
                onPressed: () => setState(() => _works.removeAt(index)),
              ),
            ],
          ),
          const Divider(height: 18),
          TextFormField(
            controller: item.companyCtrl,
            decoration: _fieldDecoration('公司'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.positionCtrl,
            decoration: _fieldDecoration('职位'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.techStackCtrl,
            decoration: _fieldDecoration(
              '技术栈',
              hintText: '逗号分隔，如: C, RT-Thread',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.descCtrl,
            decoration: _fieldDecoration('描述', hintText: '换行自动转圆点列表'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildEduCard(int index, _EduEditItem item) {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '教育 ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Switch(
                value: item.isVisible,
                onChanged: (v) => setState(() => item.isVisible = v),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.red,
                ),
                onPressed: () => setState(() => _educations.removeAt(index)),
              ),
            ],
          ),
          const Divider(height: 18),
          TextFormField(
            controller: item.schoolCtrl,
            decoration: _fieldDecoration('学校'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.majorCtrl,
            decoration: _fieldDecoration('专业'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.degreeCtrl,
            decoration: _fieldDecoration('学历'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(int index, _SkillEditItem item) {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '技能 ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              AppPill(
                label: '熟练度 ${item.proficiency}/5',
                color: AppColors.blue,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 19),
                onPressed: () {
                  if (item.proficiency < 5) {
                    setState(() => item.proficiency++);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 19),
                onPressed: () {
                  if (item.proficiency > 1) {
                    setState(() => item.proficiency--);
                  }
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.red,
                ),
                onPressed: () => setState(() => _skills.removeAt(index)),
              ),
            ],
          ),
          const Divider(height: 18),
          TextFormField(
            controller: item.nameCtrl,
            decoration: _fieldDecoration('技能名称'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.categoryCtrl,
            decoration: _fieldDecoration(
              '分类',
              hintText: 'language / framework / tool / soft',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(int index, _ProjectEditItem item) {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '项目 ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Switch(
                value: item.isVisible,
                onChanged: (v) => setState(() => item.isVisible = v),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: AppColors.red,
                ),
                onPressed: () => setState(() => _projects.removeAt(index)),
              ),
            ],
          ),
          const Divider(height: 18),
          TextFormField(
            controller: item.nameCtrl,
            decoration: _fieldDecoration('项目名称'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.roleCtrl,
            decoration: _fieldDecoration('角色'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.techStackCtrl,
            decoration: _fieldDecoration('核心技术栈', hintText: '逗号分隔'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.descCtrl,
            decoration: _fieldDecoration('描述', hintText: '换行自动转圆点列表'),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.keyDeliverablesCtrl,
            decoration: _fieldDecoration('关键交付', hintText: '每行一条，会在模板中显示为项目亮点'),
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item.badgesCtrl,
            decoration: _fieldDecoration(
              '项目标签',
              hintText: '逗号或换行分隔，会在模板中显示为徽章',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  List<String> _splitLines(String value) => value
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  List<String> _splitDelimitedList(String value) => value
      .split(RegExp(r'[,，;；\r\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

// ===== 编辑项数据类 =====

class _WorkEditItem {
  final int? id;
  final TextEditingController companyCtrl;
  final TextEditingController positionCtrl;
  final TextEditingController descCtrl;
  final TextEditingController techStackCtrl;
  bool isVisible;

  _WorkEditItem({
    this.id,
    required this.companyCtrl,
    required this.positionCtrl,
    required this.descCtrl,
    required this.techStackCtrl,
    this.isVisible = true,
  });
}

class _EduEditItem {
  final int? id;
  final TextEditingController schoolCtrl;
  final TextEditingController majorCtrl;
  final TextEditingController degreeCtrl;
  bool isVisible;

  _EduEditItem({
    this.id,
    required this.schoolCtrl,
    required this.majorCtrl,
    required this.degreeCtrl,
    this.isVisible = true,
  });
}

class _SkillEditItem {
  final int? id;
  final TextEditingController nameCtrl;
  final TextEditingController categoryCtrl;
  int proficiency;
  bool isVisible;

  _SkillEditItem({
    this.id,
    required this.nameCtrl,
    required this.categoryCtrl,
    this.proficiency = 3,
    this.isVisible = true,
  });
}

class _ProjectEditItem {
  final int? id;
  final TextEditingController nameCtrl;
  final TextEditingController roleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController techStackCtrl;
  final TextEditingController keyDeliverablesCtrl;
  final TextEditingController badgesCtrl;
  bool isVisible;

  _ProjectEditItem({
    this.id,
    required this.nameCtrl,
    required this.roleCtrl,
    required this.descCtrl,
    required this.techStackCtrl,
    required this.keyDeliverablesCtrl,
    required this.badgesCtrl,
    this.isVisible = true,
  });
}
