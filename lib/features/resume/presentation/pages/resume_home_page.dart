/// 简历首页 — 默认预览模式，点击编辑进入长条滑动编辑页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/resume_entity.dart';
import '../providers/resume_providers.dart';

class ResumeHomePage extends ConsumerWidget {
  const ResumeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: () => _exportPDF(ref),
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
                    dense: true,
                  )),
              const PopupMenuItem(
                  value: 1,
                  child: ListTile(
                    leading: Icon(Icons.credit_card),
                    title: Text('现代卡片'),
                    dense: true,
                  )),
              const PopupMenuItem(
                  value: 2,
                  child: ListTile(
                    leading: Icon(Icons.code),
                    title: Text('技术极简'),
                    dense: true,
                  )),
            ],
          ),
        ],
      ),
      body: dataAsync.when(
        data: (data) => _buildPreview(context, data, templateId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, ResumeData data, int templateId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildTemplate(data, templateId),
      ),
    );
  }

  Widget _buildTemplate(ResumeData data, int templateId) {
    switch (templateId) {
      case 1:
        return _ModernTemplate(data);
      case 2:
        return _TechTemplate(data);
      default:
        return _ClassicTemplate(data);
    }
  }

  void _exportPDF(WidgetRef ref) {
    Share.share(
      '个人简历 - ${ref.read(resumeDataProvider).valueOrNull?.profile.fullName ?? ""}',
      subject: '个人简历',
    );
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

    // 保存个人信息
    await repo.saveProfile(ResumeProfileEntity(
      fullName: _nameCtrl.text.trim(),
      jobTitle: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      personalSummary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
      updatedAt: DateTime.now(),
    ));

    // 保存工作经历
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

    // 保存教育经历
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

    // 保存技能
    for (final s in _skills) {
      await repo.saveSkill(SkillItemEntity(
        id: s.id,
        name: s.nameCtrl.text.trim(),
        category: s.categoryCtrl.text.trim().isEmpty ? 'tool' : s.categoryCtrl.text.trim(),
        proficiency: s.proficiency,
        isVisible: s.isVisible,
      ));
    }

    // 保存项目经历
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
                    // === 个人信息 ===
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

                    // === 工作经历 ===
                    _sectionTitle('工作经历'),
                    const SizedBox(height: 8),
                    ..._works.asMap().entries.map((entry) => _buildWorkCard(entry.key, entry.value)),
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

                    // === 教育背景 ===
                    _sectionTitle('教育背景'),
                    const SizedBox(height: 8),
                    ..._educations.asMap().entries.map((entry) => _buildEduCard(entry.key, entry.value)),
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

                    // === 技能 ===
                    _sectionTitle('技能'),
                    const SizedBox(height: 8),
                    ..._skills.asMap().entries.map((entry) => _buildSkillCard(entry.key, entry.value)),
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

                    // === 项目经历 ===
                    _sectionTitle('项目经历'),
                    const SizedBox(height: 8),
                    ..._projects.asMap().entries.map((entry) => _buildProjectCard(entry.key, entry.value)),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveAll,
                        icon: const Icon(Icons.save),
                        label: const Text('保存全部'),
                      ),
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

// ===== 以下为简历模板（从预览页移入） =====

// ===== 模板 1：简洁经典 =====

class _ClassicTemplate extends StatelessWidget {
  final ResumeData data;
  const _ClassicTemplate(this.data);

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(p.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  )),
              if (p.jobTitle != null)
                Text(p.jobTitle!,
                    style: const TextStyle(fontSize: 14, color: Colors.black54)),
              if (p.email != null || p.phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${p.email ?? ""}  ${p.phone ?? ""}'.trim(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
          ),
        ),
        const Divider(height: 32),
        if (p.personalSummary != null && p.personalSummary!.isNotEmpty) ...[
          _sectionTitle('个人简介'),
          Text(p.personalSummary!, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
        ],
        if (data.workExperiences.isNotEmpty) ...[
          _sectionTitle('工作经历'),
          ...data.workExperiences.map(_workItem),
          const SizedBox(height: 16),
        ],
        if (data.educations.isNotEmpty) ...[
          _sectionTitle('教育背景'),
          ...data.educations.map(_eduItem),
          const SizedBox(height: 16),
        ],
        if (data.skills.isNotEmpty) ...[
          _sectionTitle('专业技能'),
          Wrap(
            spacing: 8, runSpacing: 4,
            children: data.skills
                .map((s) => Chip(
                      label: Text(s.name, style: const TextStyle(fontSize: 12)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (data.projects.isNotEmpty) ...[
          _sectionTitle('项目经历'),
          ...data.projects.map(_projectItem),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _workItem(WorkExperienceEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(e.company, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${e.startDate.year} - ${e.endDate?.year ?? "至今"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          Text(e.position, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (e.description != null)
            Text(e.description!, style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _eduItem(EducationEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('${e.school}  ${e.major}  ${e.degree}',
          style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _projectItem(ProjectExperienceEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (e.role != null)
            Text(e.role!, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (e.description != null)
            Text(e.description!, style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

// ===== 模板 2：现代卡片 =====

class _ModernTemplate extends StatelessWidget {
  final ResumeData data;
  const _ModernTemplate(this.data);

  @override
  Widget build(BuildContext context) {
    return const Column(children: [Text('现代卡片模板')]);
  }
}

// ===== 模板 3：技术极简 =====

class _TechTemplate extends StatelessWidget {
  final ResumeData data;
  const _TechTemplate(this.data);

  @override
  Widget build(BuildContext context) {
    return const Column(children: [Text('技术极简模板')]);
  }
}
