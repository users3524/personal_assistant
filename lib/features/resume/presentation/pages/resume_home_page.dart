/// 简历编辑页 — 分 Tab 管理所有简历数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/resume_entity.dart';
import '../../data/repositories/resume_repository_impl.dart';
import '../providers/resume_providers.dart';

class ResumeHomePage extends ConsumerStatefulWidget {
  const ResumeHomePage({super.key});

  @override
  ConsumerState<ResumeHomePage> createState() => _ResumeHomePageState();
}

class _ResumeHomePageState extends ConsumerState<ResumeHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('简历管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            tooltip: '预览简历',
            onPressed: () => context.push('/resume/preview'),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '个人信息'),
            Tab(text: '工作经历'),
            Tab(text: '教育背景'),
            Tab(text: '技能'),
            Tab(text: '项目'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ProfileTab(),
          _WorkTab(),
          _EducationTab(),
          _SkillTab(),
          _ProjectTab(),
        ],
      ),
    );
  }
}

// ===== 个人信息 Tab =====

class _ProfileTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _summaryCtrl = TextEditingController();
    _titleCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final repo = await ref.read(resumeRepositoryProvider.future);
    final p = await repo.getProfile();
    if (p != null && mounted) {
      setState(() {
        _nameCtrl.text = p.fullName;
        _emailCtrl.text = p.email ?? '';
        _phoneCtrl.text = p.phone ?? '';
        _summaryCtrl.text = p.personalSummary ?? '';
        _titleCtrl.text = p.jobTitle ?? '';
        _locationCtrl.text = p.location ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _summaryCtrl.dispose();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = await ref.read(resumeRepositoryProvider.future);
    await repo.saveProfile(ResumeProfileEntity(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      personalSummary: _summaryCtrl.text.trim().isEmpty
          ? null
          : _summaryCtrl.text.trim(),
      jobTitle: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      location:
          _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      updatedAt: DateTime.now(),
    ));
    ref.read(resumeRefreshProvider.notifier).state++;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('个人信息已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '姓名'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '姓名不能为空' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: '职位头衔'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: '邮箱'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: '手机号'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: '所在地'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryCtrl,
              decoration: const InputDecoration(
                labelText: '个人简介',
                hintText: '简短介绍自己...',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('保存信息'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 工作经历 Tab =====

class _WorkTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ResumeListSection<WorkExperienceEntity>(
      title: '工作经历',
      future: ref
          .watch(resumeRepositoryProvider.future)
          .then((r) => r.getWorkExperiences()),
      buildCard: (exp, onEdit, onDelete, onToggle) => Card(
        key: ValueKey(exp.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(exp.company,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: exp.isVisible,
                    onChanged: (_) => onToggle(),
                  ),
                  IconButton(
                      icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
                  IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: onDelete),
                ],
              ),
              Text(exp.position,
                  style: const TextStyle(color: Colors.grey)),
              Text(
                '${exp.startDate.year}-${exp.startDate.month} 至今',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
      addItem: () => _showWorkForm(context, ref),
      deleteItem: (id) =>
          ref.read(resumeRepositoryProvider.future).then((r) => r.deleteWorkExperience(id)),
      toggleItem: (exp) {
        final updated = exp.copyWith(isVisible: !exp.isVisible);
        ref.read(resumeRepositoryProvider.future).then((r) => r.saveWorkExperience(updated));
      },
    );
  }

  void _showWorkForm(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加工作经历'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '公司')),
              TextField(
                  controller: posCtrl,
                  decoration: const InputDecoration(labelText: '职位')),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final repo = await ref.read(resumeRepositoryProvider.future);
              await repo.saveWorkExperience(WorkExperienceEntity(
                company: nameCtrl.text.trim(),
                position: posCtrl.text.trim(),
                description: descCtrl.text.trim(),
                startDate: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

// ===== 教育经历 Tab =====

class _EducationTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ResumeListSection<EducationEntity>(
      title: '教育背景',
      future: ref
          .watch(resumeRepositoryProvider.future)
          .then((r) => r.getEducations()),
      buildCard: (edu, onEdit, onDelete, onToggle) => Card(
        child: ListTile(
          title: Text(edu.school),
          subtitle: Text('${edu.major} · ${edu.degree}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: edu.isVisible, onChanged: (_) => onToggle()),
              IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: onDelete),
            ],
          ),
        ),
      ),
      addItem: () => _showEduForm(context, ref),
      deleteItem: (id) =>
          ref.read(resumeRepositoryProvider.future).then((r) => r.deleteEducation(id)),
      toggleItem: (edu) {
        final updated = edu.copyWith(isVisible: !edu.isVisible);
        ref.read(resumeRepositoryProvider.future).then((r) => r.saveEducation(updated));
      },
    );
  }

  void _showEduForm(BuildContext context, WidgetRef ref) {
    final schoolCtrl = TextEditingController();
    final majorCtrl = TextEditingController();
    String degree = '本科';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('添加教育经历'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: schoolCtrl,
                  decoration: const InputDecoration(labelText: '学校')),
              TextField(
                  controller: majorCtrl,
                  decoration: const InputDecoration(labelText: '专业')),
              DropdownButtonFormField<String>(
                initialValue: degree,
                items: ['博士', '硕士', '本科', '大专']
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => degree = v!),
                decoration: const InputDecoration(labelText: '学历'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final repo = await ref.read(resumeRepositoryProvider.future);
                await repo.saveEducation(EducationEntity(
                  school: schoolCtrl.text.trim(),
                  major: majorCtrl.text.trim(),
                  degree: degree,
                  startDate: DateTime.now(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 技能 Tab =====

class _SkillTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ResumeListSection<SkillItemEntity>(
      title: '技能',
      future: ref
          .watch(resumeRepositoryProvider.future)
          .then((r) => r.getSkills()),
      buildCard: (skill, onEdit, onDelete, onToggle) => Card(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${skill.proficiency}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary)),
            ),
          ),
          title: Text(skill.name),
          subtitle: Text(skill.category),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: skill.isVisible, onChanged: (_) => onToggle()),
              IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: onDelete),
            ],
          ),
        ),
      ),
      addItem: () => _showSkillForm(context, ref),
      deleteItem: (id) =>
          ref.read(resumeRepositoryProvider.future).then((r) => r.deleteSkill(id)),
      toggleItem: (skill) {
        final updated = skill.copyWith(isVisible: !skill.isVisible);
        ref.read(resumeRepositoryProvider.future).then((r) => r.saveSkill(updated));
      },
    );
  }

  void _showSkillForm(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    String category = 'language';
    int proficiency = 3;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('添加技能'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '技能名称')),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: ['language', 'framework', 'tool', 'soft']
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text({
                              'language': '编程语言',
                              'framework': '框架',
                              'tool': '工具',
                              'soft': '软技能'
                            }[c]!)))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
                decoration: const InputDecoration(labelText: '分类'),
              ),
              const SizedBox(height: 8),
              Text('熟练度: $proficiency/5'),
              Slider(
                value: proficiency.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (v) => setState(() => proficiency = v.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            TextButton(
              onPressed: () async {
                final repo = await ref.read(resumeRepositoryProvider.future);
                await repo.saveSkill(SkillItemEntity(
                  name: nameCtrl.text.trim(),
                  category: category,
                  proficiency: proficiency,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== 项目经历 Tab =====

class _ProjectTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ResumeListSection<ProjectExperienceEntity>(
      title: '项目经历',
      future: ref
          .watch(resumeRepositoryProvider.future)
          .then((r) => r.getProjects()),
      buildCard: (proj, onEdit, onDelete, onToggle) => Card(
        child: ListTile(
          title: Text(proj.name),
          subtitle: Text(proj.role ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: proj.isVisible, onChanged: (_) => onToggle()),
              IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: onDelete),
            ],
          ),
        ),
      ),
      addItem: () => _showProjectForm(context, ref),
      deleteItem: (id) =>
          ref.read(resumeRepositoryProvider.future).then((r) => r.deleteProject(id)),
      toggleItem: (proj) {
        final updated = proj.copyWith(isVisible: !proj.isVisible);
        ref.read(resumeRepositoryProvider.future).then((r) => r.saveProject(updated));
      },
    );
  }

  void _showProjectForm(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加项目经历'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '项目名称')),
              TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(labelText: '角色')),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final repo = await ref.read(resumeRepositoryProvider.future);
              await repo.saveProject(ProjectExperienceEntity(
                name: nameCtrl.text.trim(),
                role: roleCtrl.text.trim(),
                description: descCtrl.text.trim(),
                startDate: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

// ===== 通用列表组件 =====

class _ResumeListSection<T> extends StatelessWidget {
  final String title;
  final Future<List<T>> future;
  final Widget Function(T item, VoidCallback onEdit, VoidCallback onDelete,
      VoidCallback onToggle) buildCard;
  final VoidCallback addItem;
  final Future<void> Function(int id) deleteItem;
  final void Function(T item) toggleItem;

  const _ResumeListSection({
    required this.title,
    required this.future,
    required this.buildCard,
    required this.addItem,
    required this.deleteItem,
    required this.toggleItem,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == items.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton.icon(
                  onPressed: addItem,
                  icon: const Icon(Icons.add),
                  label: Text('添加$title'),
                ),
              );
            }
            final item = items[index];
            return buildCard(
              item,
              () {}, // edit
              () async {
                // 获取 id
                try {
                  final id = (item as dynamic).id as int;
                  await deleteItem(id);
                } catch (_) {}
              },
              () => toggleItem(item),
            );
          },
        );
      },
    );
  }
}
