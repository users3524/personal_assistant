/// 简历首页 — 默认预览模式，点击编辑进入长条滑动编辑页。
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/resume_entity.dart';
import '../providers/resume_providers.dart';
import '../widgets/resume_templates.dart';

class ResumeHomePage extends ConsumerStatefulWidget {
  const ResumeHomePage({super.key});

  @override
  ConsumerState<ResumeHomePage> createState() => _ResumeHomePageState();
}

class _ResumeHomePageState extends ConsumerState<ResumeHomePage> {
  final _repaintKey = GlobalKey();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(resumeDataProvider);
    final templateId = ref.watch(selectedTemplateIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('简历预览'),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.push('/settings'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑简历',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _ResumeEditPage()),
            ),
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            tooltip: '导出分享',
            onPressed: _isExporting ? null : _exportAsImage,
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.design_services),
            tooltip: '切换模板',
            onSelected: (id) =>
                ref.read(selectedTemplateIdProvider.notifier).state = id,
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 0,
                  child: ListTile(
                    leading: Icon(Icons.article),
                    title: Text('简洁经典'),
                    subtitle: Text('单栏布局，适合传统行业'),
                    dense: true,
                  )),
              const PopupMenuItem(
                  value: 1,
                  child: ListTile(
                    leading: Icon(Icons.credit_card),
                    title: Text('现代卡片'),
                    subtitle: Text('双栏布局，适合设计/产品岗'),
                    dense: true,
                  )),
              const PopupMenuItem(
                  value: 2,
                  child: ListTile(
                    leading: Icon(Icons.code),
                    title: Text('技术极简'),
                    subtitle: Text('等宽字体，适合程序员'),
                    dense: true,
                  )),
            ],
          ),
        ],
      ),
      body: dataAsync.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildTemplate(data, templateId),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
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
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取预览区域');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('编码失败');

      final dir = Directory.systemTemp;
      final file = File('${dir.path}/resume_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '个人简历 - ${ref.read(resumeDataProvider).valueOrNull?.profile.fullName ?? ""}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
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
        _works = works.map((w) => _WorkEditItem(
          id: w.id,
          companyCtrl: TextEditingController(text: w.company),
          positionCtrl: TextEditingController(text: w.position),
          descCtrl: TextEditingController(text: w.description ?? ''),
          isVisible: w.isVisible,
        )).toList();
        _educations = educations.map((e) => _EduEditItem(
          id: e.id,
          schoolCtrl: TextEditingController(text: e.school),
          majorCtrl: TextEditingController(text: e.major),
          degreeCtrl: TextEditingController(text: e.degree),
          isVisible: e.isVisible,
        )).toList();
        _skills = skills.map((s) => _SkillEditItem(
          id: s.id,
          nameCtrl: TextEditingController(text: s.name),
          categoryCtrl: TextEditingController(text: s.category),
          proficiency: s.proficiency,
          isVisible: s.isVisible,
        )).toList();
        _projects = projects.map((p) => _ProjectEditItem(
          id: p.id,
          nameCtrl: TextEditingController(text: p.name),
          roleCtrl: TextEditingController(text: p.role ?? ''),
          descCtrl: TextEditingController(text: p.description ?? ''),
          isVisible: p.isVisible,
        )).toList();
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
    }
    super.dispose();
  }

  Future<void> _saveAll() async {
    final repo = await ref.read(resumeRepositoryProvider.future);

    await repo.saveProfile(ResumeProfileEntity(
      fullName: _nameCtrl.text.trim(),
      jobTitle: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      personalSummary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
      updatedAt: DateTime.now(),
    ));

    for (final w in _works) {
      await repo.saveWorkExperience(WorkExperienceEntity(
        id: w.id,
        company: w.companyCtrl.text.trim(),
        position: w.positionCtrl.text.trim(),
        description: w.descCtrl.text.trim().isEmpty ? null : w.descCtrl.text.trim(),
        startDate: DateTime.now(),
        isVisible: w.isVisible,
      ));
    }

    for (final e in _educations) {
      await repo.saveEducation(EducationEntity(
        id: e.id,
        school: e.schoolCtrl.text.trim(),
        major: e.majorCtrl.text.trim(),
        degree: e.degreeCtrl.text.trim().isEmpty ? '本科' : e.degreeCtrl.text.trim(),
        startDate: DateTime.now(),
        isVisible: e.isVisible,
      ));
    }

    for (final s in _skills) {
      await repo.saveSkill(SkillItemEntity(
        id: s.id,
        name: s.nameCtrl.text.trim(),
        category: s.categoryCtrl.text.trim().isEmpty ? 'tool' : s.categoryCtrl.text.trim(),
        proficiency: s.proficiency,
        isVisible: s.isVisible,
      ));
    }

    for (final p in _projects) {
      await repo.saveProject(ProjectExperienceEntity(
        id: p.id,
        name: p.nameCtrl.text.trim(),
        role: p.roleCtrl.text.trim().isEmpty ? null : p.roleCtrl.text.trim(),
        description: p.descCtrl.text.trim().isEmpty ? null : p.descCtrl.text.trim(),
        startDate: DateTime.now(),
        isVisible: p.isVisible,
      ));
    }

    ref.read(resumeRefreshProvider.notifier).state++;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('简历已保存')),
      );
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
                      decoration: const InputDecoration(labelText: '姓名 *', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? '姓名不能为空' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: '职位头衔', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: '邮箱', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(labelText: '所在地', border: OutlineInputBorder()),
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
                      itemBuilder: (context, index) => ReorderableDragStartListener(
                        key: ValueKey('work_$index'),
                        index: index,
                        child: _buildWorkCard(index, _works[index]),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _works.add(_WorkEditItem(
                          companyCtrl: TextEditingController(),
                          positionCtrl: TextEditingController(),
                          descCtrl: TextEditingController(),
                        )));
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
                      itemBuilder: (context, index) => ReorderableDragStartListener(
                        key: ValueKey('edu_$index'),
                        index: index,
                        child: _buildEduCard(index, _educations[index]),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _educations.add(_EduEditItem(
                          schoolCtrl: TextEditingController(),
                          majorCtrl: TextEditingController(),
                          degreeCtrl: TextEditingController(text: '本科'),
                        )));
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
                      itemBuilder: (context, index) => ReorderableDragStartListener(
                        key: ValueKey('skill_$index'),
                        index: index,
                        child: _buildSkillCard(index, _skills[index]),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _skills.add(_SkillEditItem(
                          nameCtrl: TextEditingController(),
                          categoryCtrl: TextEditingController(text: 'tool'),
                        )));
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
                      itemBuilder: (context, index) => ReorderableDragStartListener(
                        key: ValueKey('proj_$index'),
                        index: index,
                        child: _buildProjectCard(index, _projects[index]),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _projects.add(_ProjectEditItem(
                          nameCtrl: TextEditingController(),
                          roleCtrl: TextEditingController(),
                          descCtrl: TextEditingController(),
                        )));
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
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
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
                  child: const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                Text('工作 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: item.isVisible,
                  onChanged: (v) => setState(() => item.isVisible = v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _works.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.companyCtrl,
              decoration: const InputDecoration(labelText: '公司', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.positionCtrl,
              decoration: const InputDecoration(labelText: '职位', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.descCtrl,
              decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder(), isDense: true),
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
                  child: const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                Text('教育 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: item.isVisible,
                  onChanged: (v) => setState(() => item.isVisible = v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _educations.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.schoolCtrl,
              decoration: const InputDecoration(labelText: '学校', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.majorCtrl,
              decoration: const InputDecoration(labelText: '专业', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.degreeCtrl,
              decoration: const InputDecoration(labelText: '学历', border: OutlineInputBorder(), isDense: true),
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
                  child: const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                Text('技能 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('熟练度: ${item.proficiency}/5'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () {
                    if (item.proficiency < 5) setState(() => item.proficiency++);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    if (item.proficiency > 1) setState(() => item.proficiency--);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _skills.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.nameCtrl,
              decoration: const InputDecoration(labelText: '技能名称', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.categoryCtrl,
              decoration: const InputDecoration(
                labelText: '分类',
                hintText: 'language / framework / tool / soft',
                border: OutlineInputBorder(), isDense: true,
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
                  child: const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
                ),
                const SizedBox(width: 4),
                Text('项目 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: item.isVisible,
                  onChanged: (v) => setState(() => item.isVisible = v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _projects.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.nameCtrl,
              decoration: const InputDecoration(labelText: '项目名称', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.roleCtrl,
              decoration: const InputDecoration(labelText: '角色', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.descCtrl,
              decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder(), isDense: true),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 编辑项数据类 =====

class _WorkEditItem {
  final int? id;
  final TextEditingController companyCtrl;
  final TextEditingController positionCtrl;
  final TextEditingController descCtrl;
  bool isVisible;

  _WorkEditItem({
    this.id,
    required this.companyCtrl,
    required this.positionCtrl,
    required this.descCtrl,
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
  bool isVisible;

  _ProjectEditItem({
    this.id,
    required this.nameCtrl,
    required this.roleCtrl,
    required this.descCtrl,
    this.isVisible = true,
  });
}
