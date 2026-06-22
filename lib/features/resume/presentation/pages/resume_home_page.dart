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
      appBar: AppBar(
        title: const Text('编辑简历'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveAll,
            child: const Text('保存'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('个人信息'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '姓名 *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '姓名不能为空' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: '职位头衔',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: '手机号',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(
                        labelText: '所在地',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _summaryCtrl,
                      decoration: const InputDecoration(
                        labelText: '个人简介',
                        hintText: '简短介绍自己...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),
                    const Divider(),

                    _sectionTitle('工作经历'),
                    const SizedBox(height: 8),
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
                      itemBuilder: (context, index) =>
                          ReorderableDragStartListener(
                            key: ValueKey('work_$index'),
                            index: index,
                            child: _buildWorkCard(index, _works[index]),
                          ),
                    ),
                    OutlinedButton.icon(
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
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加工作经历'),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),

                    _sectionTitle('教育背景'),
                    const SizedBox(height: 8),
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
                      itemBuilder: (context, index) =>
                          ReorderableDragStartListener(
                            key: ValueKey('edu_$index'),
                            index: index,
                            child: _buildEduCard(index, _educations[index]),
                          ),
                    ),
                    OutlinedButton.icon(
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
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加教育经历'),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),

                    _sectionTitle('技能'),
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
                      itemBuilder: (context, index) =>
                          ReorderableDragStartListener(
                            key: ValueKey('skill_$index'),
                            index: index,
                            child: _buildSkillCard(index, _skills[index]),
                          ),
                    ),
                    OutlinedButton.icon(
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
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加技能'),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),

                    _sectionTitle('项目经历'),
                    const SizedBox(height: 8),
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
                      itemBuilder: (context, index) =>
                          ReorderableDragStartListener(
                            key: ValueKey('proj_$index'),
                            index: index,
                            child: _buildProjectCard(index, _projects[index]),
                          ),
                    ),
                    OutlinedButton.icon(
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
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加项目经历'),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildWorkCard(int index, _WorkEditItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '工作 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Switch(
                  value: item.isVisible,
                  onChanged: (v) => setState(() => item.isVisible = v),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  onPressed: () => setState(() => _works.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.companyCtrl,
              decoration: const InputDecoration(
                labelText: '公司',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.positionCtrl,
              decoration: const InputDecoration(
                labelText: '职位',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.techStackCtrl,
              decoration: const InputDecoration(
                labelText: '技术栈',
                hintText: '逗号分隔，如: C, RT-Thread',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.descCtrl,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '换行自动转圆点列表',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEduCard(int index, _EduEditItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '教育 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Switch(
                  value: item.isVisible,
                  onChanged: (v) => setState(() => item.isVisible = v),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  onPressed: () => setState(() => _educations.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.schoolCtrl,
              decoration: const InputDecoration(
                labelText: '学校',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.majorCtrl,
              decoration: const InputDecoration(
                labelText: '专业',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.degreeCtrl,
              decoration: const InputDecoration(
                labelText: '学历',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillCard(int index, _SkillEditItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '技能 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text('熟练度: ${item.proficiency}/5'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () {
                    if (item.proficiency < 5) {
                      setState(() => item.proficiency++);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    if (item.proficiency > 1) {
                      setState(() => item.proficiency--);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  onPressed: () => setState(() => _skills.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.nameCtrl,
              decoration: const InputDecoration(
                labelText: '技能名称',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.categoryCtrl,
              decoration: const InputDecoration(
                labelText: '分类',
                hintText: 'language / framework / tool / soft',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(int index, _ProjectEditItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '项目 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Switch(
                  value: item.isVisible,
                  onChanged: (v) => setState(() => item.isVisible = v),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  onPressed: () => setState(() => _projects.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.nameCtrl,
              decoration: const InputDecoration(
                labelText: '项目名称',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.roleCtrl,
              decoration: const InputDecoration(
                labelText: '角色',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.techStackCtrl,
              decoration: const InputDecoration(
                labelText: '核心技术栈',
                hintText: '逗号分隔',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.descCtrl,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '换行自动转圆点列表',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.keyDeliverablesCtrl,
              decoration: const InputDecoration(
                labelText: '关键交付',
                hintText: '每行一条，会在模板中显示为项目亮点',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.badgesCtrl,
              decoration: const InputDecoration(
                labelText: '项目标签',
                hintText: '逗号或换行分隔，会在模板中显示为徽章',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
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
