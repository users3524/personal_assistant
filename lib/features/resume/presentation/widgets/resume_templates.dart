/// 简历模板组件 — 三个可切换的排版风格。
///
/// 设计参考：awesome-resume-for-chinese、visiky/resume、木及简历
///
/// - 简洁经典：单栏布局，传统商务风格，适合传统行业
/// - 现代卡片：双栏布局，左侧彩色侧边栏 + 右侧内容卡片，适合设计/产品岗
/// - 技术极简：等宽字体 + 分割线，极简克制，适合程序员
library;

import 'package:flutter/material.dart';

import '../../domain/entities/resume_entity.dart';

// ===== 核心排版工具函数 =====

/// 将换行文本转为 Bullet Points 列表
Widget buildBulletPoints(String? text) {
  if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
  final points = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: points.map((p) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF666666))),
          Expanded(child: Text(p, style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF444444)))),
        ],
      ),
    )).toList(),
  );
}

/// 技术栈蓝色徽章
Widget buildTechStack(List<String> stack) {
  if (stack.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      spacing: 4, runSpacing: 2,
      children: stack.map((tech) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FE),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(tech, style: const TextStyle(fontSize: 9, color: Color(0xFF1A73E8))),
      )).toList(),
    ),
  );
}

// ======================================================================
// 模板 1：简洁经典 — 单栏商务风
// ======================================================================

class ClassicResumeTemplate extends StatelessWidget {
  final ResumeData data;
  const ClassicResumeTemplate(this.data);

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 页眉：姓名 + 头衔 + 联系方式单行
        Center(
          child: Column(
            children: [
              Text(p.fullName,
                  style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E),
                    letterSpacing: 2,
                  )),
              if (p.jobTitle != null && p.jobTitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(p.jobTitle!,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF555555))),
                ),
              const SizedBox(height: 8),
              // 联系方式单行
              Wrap(
                spacing: 16,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  if (p.email != null && p.email!.isNotEmpty)
                    _contactChip(Icons.email_outlined, p.email!),
                  if (p.phone != null && p.phone!.isNotEmpty)
                    _contactChip(Icons.phone_outlined, p.phone!),
                  if (p.location != null && p.location!.isNotEmpty)
                    _contactChip(Icons.location_on_outlined, p.location!),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 32, thickness: 1),

        // 个人简介
        if (p.personalSummary != null && p.personalSummary!.isNotEmpty) ...[
          _secTitle('个人简介'),
          Text(p.personalSummary!,
              style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF333333))),
          const SizedBox(height: 20),
        ],

        // 工作经历
        if (data.workExperiences.isNotEmpty) ...[
          _secTitle('工作经历'),
          ...data.workExperiences.map(_workItem),
          const SizedBox(height: 16),
        ],

        // 教育背景
        if (data.educations.isNotEmpty) ...[
          _secTitle('教育背景'),
          ...data.educations.map(_eduItem),
          const SizedBox(height: 16),
        ],

        // 专业技能
        if (data.skills.isNotEmpty) ...[
          _secTitle('专业技能'),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: data.skills.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(s.name, style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // 项目经历
        if (data.projects.isNotEmpty) ...[
          _secTitle('项目经历'),
          ...data.projects.map(_projectItem),
        ],
      ],
    );
  }

  Widget _contactChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF666666)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
      ],
    );
  }

  Widget _secTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: const Color(0xFF1A1A2E)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }

  Widget _workItem(WorkExperienceEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(e.company,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1A2E))),
              ),
              const SizedBox(width: 8),
              Text('${e.startDate.year} - ${e.endDate?.year ?? "至今"}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ],
          ),
          const SizedBox(height: 2),
          Text(e.position,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w500)),
          buildTechStack(e.techStack),
          buildBulletPoints(e.description),
        ],
      ),
    );
  }

  Widget _eduItem(EducationEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('${e.school} · ${e.major}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
          ),
          Text(e.degree,
              style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
        ],
      ),
    );
  }

  Widget _projectItem(ProjectExperienceEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A2E))),
              ),
              if (e.role != null && e.role!.isNotEmpty)
                Text(e.role!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ],
          ),
          if (e.badges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4, runSpacing: 2,
                children: e.badges.map((b) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(b, style: const TextStyle(fontSize: 9, color: Color(0xFFE65100))),
                )).toList(),
              ),
            ),
          buildTechStack(e.techStack),
          if (e.keyDeliverables.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: e.keyDeliverables.map((d) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      Expanded(child: Text(d, style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF555555)))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          buildBulletPoints(e.description),
        ],
      ),
    );
  }
}

// ======================================================================
// 模板 2：现代卡片 — 双栏 + 左侧彩色侧边栏
// ======================================================================

class ModernResumeTemplate extends StatelessWidget {
  final ResumeData data;
  const ModernResumeTemplate(this.data);

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    const accentColor = Color(0xFF2D6A4F);
    const lightBg = Color(0xFFF8F9FA);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：侧边栏（深色背景）
        SizedBox(
          width: 120,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.fullName,
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                    )),
                if (p.jobTitle != null && p.jobTitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p.jobTitle!,
                        style: const TextStyle(fontSize: 10, color: Color(0xFFCCE3DE))),
                  ),
                const SizedBox(height: 16),
                _sidebarSection('联系方式', [
                  if (p.email != null && p.email!.isNotEmpty) p.email!,
                  if (p.phone != null && p.phone!.isNotEmpty) p.phone!,
                  if (p.location != null && p.location!.isNotEmpty) p.location!,
                ]),
                const SizedBox(height: 16),
                if (data.skills.isNotEmpty)
                  _sidebarSection('技能', data.skills.map((s) => s.name).toList()),
                const SizedBox(height: 16),
                if (data.educations.isNotEmpty)
                  _sidebarSection('教育', data.educations.map((e) => e.school).toList()),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 右侧：主内容区
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.personalSummary != null && p.personalSummary!.isNotEmpty) ...[
                _card('关于我', Text(p.personalSummary!,
                    style: const TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF444444)))),
                const SizedBox(height: 12),
              ],
              if (data.workExperiences.isNotEmpty) ...[
                _card('工作经历', Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.workExperiences.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(e.company,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A2E))),
                            ),
                            Text('${e.startDate.year} - ${e.endDate?.year ?? "至今"}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
                          ],
                        ),
                        Text(e.position,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
                        if (e.description != null && e.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(e.description!,
                                style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF666666))),
                          ),
                      ],
                    ),
                  )).toList(),
                )),
              ],
              if (data.projects.isNotEmpty) ...[
                const SizedBox(height: 12),
                _card('项目经历', Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.projects.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1A1A2E))),
                        if (e.role != null && e.role!.isNotEmpty)
                          Text(e.role!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
                        if (e.description != null && e.description!.isNotEmpty)
                          Text(e.description!,
                              style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF666666))),
                      ],
                    ),
                  )).toList(),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebarSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCCE3DE),
            )),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(item,
              style: const TextStyle(fontSize: 10, color: Color(0xFFE9F5F0))),
        )),
      ],
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E),
              )),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ======================================================================
// 模板 3：技术极简 — 等宽字体 + 分割线
// ======================================================================

class TechResumeTemplate extends StatelessWidget {
  final ResumeData data;
  const TechResumeTemplate(this.data);

  @override
  Widget build(BuildContext context) {
    final p = data.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 页眉：类似 Markdown 标题
        Center(
          child: Column(
            children: [
              Text(p.fullName,
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600,
                    fontFamily: 'monospace', color: Color(0xFF000000),
                  )),
              if (p.jobTitle != null && p.jobTitle!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('# ${p.jobTitle!}',
                      style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace',
                        color: Color(0xFF888888),
                      )),
                ),
              const SizedBox(height: 8),
              // 联系方式行
              Text(
                [
                  if (p.email != null && p.email!.isNotEmpty) p.email!,
                  if (p.phone != null && p.phone!.isNotEmpty) p.phone!,
                  if (p.location != null && p.location!.isNotEmpty) p.location!,
                ].join('  |  '),
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFAAAAAA)),
              ),
            ],
          ),
        ),
        const Divider(height: 24, color: Color(0xFF000000)),

        // 个人简介
        if (p.personalSummary != null && p.personalSummary!.isNotEmpty) ...[
          _mdTitle('# 简介'),
          Text(p.personalSummary!,
              style: const TextStyle(fontSize: 12, height: 1.6, fontFamily: 'monospace', color: Color(0xFF333333))),
          const SizedBox(height: 16),
        ],

        // 工作经历
        if (data.workExperiences.isNotEmpty) ...[
          _mdTitle('# 经历'),
          ...data.workExperiences.map(_workItem),
          const SizedBox(height: 12),
        ],

        // 教育背景
        if (data.educations.isNotEmpty) ...[
          _mdTitle('# 教育'),
          ...data.educations.map(_eduItem),
          const SizedBox(height: 12),
        ],

        // 技能
        if (data.skills.isNotEmpty) ...[
          _mdTitle('# 技能'),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: data.skills.map((s) => Text(
              '[${s.name}]',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF555555)),
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // 项目
        if (data.projects.isNotEmpty) ...[
          _mdTitle('# 项目'),
          ...data.projects.map(_projectItem),
        ],
      ],
    );
  }

  Widget _mdTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            fontFamily: 'monospace', color: Color(0xFF000000),
          )),
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
              Text('## ${e.company}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace', color: Color(0xFF333333))),
              const Spacer(),
              Text('${e.startDate.year}-${e.endDate?.year ?? "至今"}',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFFAAAAAA))),
            ],
          ),
          Text('> ${e.position}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF888888))),
          if (e.description != null && e.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(e.description!,
                  style: const TextStyle(fontSize: 11, height: 1.5, fontFamily: 'monospace', color: Color(0xFF666666))),
            ),
        ],
      ),
    );
  }

  Widget _eduItem(EducationEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('* ${e.school} / ${e.major} (${e.degree})',
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF444444))),
    );
  }

  Widget _projectItem(ProjectExperienceEntity e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('## ${e.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'monospace', color: Color(0xFF333333))),
              if (e.role != null && e.role!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('(${e.role})',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF888888))),
              ],
            ],
          ),
          if (e.description != null && e.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(e.description!,
                  style: const TextStyle(fontSize: 11, height: 1.5, fontFamily: 'monospace', color: Color(0xFF666666))),
            ),
        ],
      ),
    );
  }
}
