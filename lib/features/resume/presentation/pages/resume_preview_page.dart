/// 简历预览页 — 实时预览 + 模板切换 + PDF 导出。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/resume_entity.dart';
import '../providers/resume_providers.dart';

class ResumePreviewPage extends ConsumerWidget {
  const ResumePreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(resumeDataProvider);
    final templateId = ref.watch(selectedTemplateIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('简历预览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: () => _exportPDF(context, ref),
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

  Widget _buildPreview(
    BuildContext context,
    ResumeData data,
    int templateId,
  ) {
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

  void _exportPDF(BuildContext context, WidgetRef ref) {
    Share.share(
      '个人简历 - ${ref.read(resumeDataProvider).valueOrNull?.profile.fullName ?? ""}',
      subject: '个人简历',
    );
  }
}

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
        // 头部
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
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black54)),
              if (p.email != null || p.phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text('${p.email ?? ""}  ${p.phone ?? ""}'.trim(),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                ),
            ],
          ),
        ),
        const Divider(height: 32),
        // 简介
        if (p.personalSummary != null && p.personalSummary!.isNotEmpty) ...[
          _sectionTitle('个人简介'),
          Text(p.personalSummary!,
              style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
        ],
        // 工作经历
        if (data.workExperiences.isNotEmpty) ...[
          _sectionTitle('工作经历'),
          ...data.workExperiences.map(_workItem),
          const SizedBox(height: 16),
        ],
        // 教育
        if (data.educations.isNotEmpty) ...[
          _sectionTitle('教育背景'),
          ...data.educations.map(_eduItem),
          const SizedBox(height: 16),
        ],
        // 技能
        if (data.skills.isNotEmpty) ...[
          _sectionTitle('专业技能'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: data.skills
                .map((s) => Chip(
                      label: Text(s.name,
                          style: const TextStyle(fontSize: 12)),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        // 项目
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
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _workItem(WorkExperienceEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(e.company,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${e.startDate.year} - ${e.endDate?.year ?? "至今"}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          Text(e.position,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (e.description != null)
            Text(e.description!,
                style: const TextStyle(fontSize: 12, height: 1.4)),
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
          Text(e.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (e.role != null)
            Text(e.role!,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          if (e.description != null)
            Text(e.description!,
                style: const TextStyle(fontSize: 12, height: 1.4)),
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
    final p = data.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 彩色头部
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.indigo.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.fullName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              if (p.jobTitle != null)
                Text(p.jobTitle!,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70)),
              if (p.email != null || p.phone != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '${p.email ?? ""}  |  ${p.phone ?? ""}'.trim(),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white60)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 双栏布局
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：技能 + 教育
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.skills.isNotEmpty) ...[
                    _card('技能', Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: data.skills.map((s) => Chip(
                        label: Text(s.name, style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    )),
                    const SizedBox(height: 12),
                  ],
                  if (data.educations.isNotEmpty) ...[
                    _card('教育', Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.educations.map((e) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.school, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${e.major} · ${e.degree}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ).toList(),
                    )),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 右侧：工作经历 + 项目
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.workExperiences.isNotEmpty) ...[
                    _card('工作经历', Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: data.workExperiences.map((e) =>
                        Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(e.company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const Spacer(),
                              Text('${e.startDate.year}-${e.endDate?.year ?? "至今"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ]),
                            Text(e.position, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ).toList(),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _card(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.indigo)),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }
}

// ===== 模板 3：技术极简 =====

class _TechTemplate extends StatelessWidget {
  final ResumeData data;
  const _TechTemplate(this.data);

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 等宽字体头部
        Text('# ${p.fullName}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            )),
        if (p.jobTitle != null)
          Text('## ${p.jobTitle}',
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontFamily: 'monospace')),
        if (p.personalSummary != null && p.personalSummary!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('// ${p.personalSummary}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontFamily: 'monospace')),
        ],
        const Divider(height: 24),
        // 工作经历
        if (data.workExperiences.isNotEmpty) ...[
          _codeSection('## Work Experience'),
          ...data.workExperiences.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('### ${e.company} — ${e.position}',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(
                        '   [${e.startDate.year} - ${e.endDate?.year ?? "present"}]',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.grey)),
                    if (e.description != null)
                      Text(e.description!,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
              )),
        ],
        // 技能
        if (data.skills.isNotEmpty) ...[
          const Divider(),
          _codeSection('## Skills'),
          Text(data.skills.map((s) => s.name).join(' | '),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12)),
        ],
      ],
    );
  }

  Widget _codeSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 14)),
    );
  }
}
