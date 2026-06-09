/// 简历模块领域实体。
library;

class ResumeProfileEntity {
  final int? id;
  final String fullName;
  final String? avatarPath;
  final String? email;
  final String? phone;
  final String? personalSummary;
  final String? website;
  final String? location;
  final String? jobTitle;
  final DateTime updatedAt;

  const ResumeProfileEntity({
    this.id,
    required this.fullName,
    this.avatarPath,
    this.email,
    this.phone,
    this.personalSummary,
    this.website,
    this.location,
    this.jobTitle,
    required this.updatedAt,
  });

  ResumeProfileEntity copyWith({
    int? id,
    String? fullName,
    String? avatarPath,
    String? email,
    String? phone,
    String? personalSummary,
    String? website,
    String? location,
    String? jobTitle,
    DateTime? updatedAt,
  }) =>
      ResumeProfileEntity(
        id: id ?? this.id,
        fullName: fullName ?? this.fullName,
        avatarPath: avatarPath ?? this.avatarPath,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        personalSummary: personalSummary ?? this.personalSummary,
        website: website ?? this.website,
        location: location ?? this.location,
        jobTitle: jobTitle ?? this.jobTitle,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class WorkExperienceEntity {
  final int? id;
  final String company;
  final String position;
  final DateTime startDate;
  final DateTime? endDate;
  final String? description;
  final List<String> responsibilities;
  final List<String> techStack;
  final bool isVisible;
  final int sortOrder;

  const WorkExperienceEntity({
    this.id,
    required this.company,
    required this.position,
    required this.startDate,
    this.endDate,
    this.description,
    this.responsibilities = const [],
    this.techStack = const [],
    this.isVisible = true,
    this.sortOrder = 0,
  });

  WorkExperienceEntity copyWith({
    int? id,
    String? company,
    String? position,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    List<String>? responsibilities,
    List<String>? techStack,
    bool? isVisible,
    int? sortOrder,
  }) =>
      WorkExperienceEntity(
        id: id ?? this.id,
        company: company ?? this.company,
        position: position ?? this.position,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        description: description ?? this.description,
        responsibilities: responsibilities ?? this.responsibilities,
        techStack: techStack ?? this.techStack,
        isVisible: isVisible ?? this.isVisible,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class EducationEntity {
  final int? id;
  final String school;
  final String major;
  final String degree;
  final DateTime startDate;
  final DateTime? endDate;
  final String? description;
  final bool isVisible;
  final int sortOrder;

  const EducationEntity({
    this.id,
    required this.school,
    required this.major,
    required this.degree,
    required this.startDate,
    this.endDate,
    this.description,
    this.isVisible = true,
    this.sortOrder = 0,
  });

  EducationEntity copyWith({
    int? id,
    String? school,
    String? major,
    String? degree,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    bool? isVisible,
    int? sortOrder,
  }) =>
      EducationEntity(
        id: id ?? this.id,
        school: school ?? this.school,
        major: major ?? this.major,
        degree: degree ?? this.degree,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        description: description ?? this.description,
        isVisible: isVisible ?? this.isVisible,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class SkillItemEntity {
  final int? id;
  final String name;
  final String category;
  final int proficiency;
  final bool isVisible;
  final int sortOrder;

  const SkillItemEntity({
    this.id,
    required this.name,
    required this.category,
    this.proficiency = 3,
    this.isVisible = true,
    this.sortOrder = 0,
  });

  SkillItemEntity copyWith({
    int? id,
    String? name,
    String? category,
    int? proficiency,
    bool? isVisible,
    int? sortOrder,
  }) =>
      SkillItemEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        proficiency: proficiency ?? this.proficiency,
        isVisible: isVisible ?? this.isVisible,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class ProjectExperienceEntity {
  final int? id;
  final String name;
  final String? role;
  final String? description;
  final List<String> techStack;
  final List<String> keyDeliverables;
  final List<String> badges;
  final String? link;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isVisible;
  final int sortOrder;

  const ProjectExperienceEntity({
    this.id,
    required this.name,
    this.role,
    this.description,
    this.techStack = const [],
    this.keyDeliverables = const [],
    this.badges = const [],
    this.link,
    required this.startDate,
    this.endDate,
    this.isVisible = true,
    this.sortOrder = 0,
  });

  ProjectExperienceEntity copyWith({
    int? id,
    String? name,
    String? role,
    String? description,
    List<String>? techStack,
    List<String>? keyDeliverables,
    List<String>? badges,
    String? link,
    DateTime? startDate,
    DateTime? endDate,
    bool? isVisible,
    int? sortOrder,
  }) =>
      ProjectExperienceEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        description: description ?? this.description,
        techStack: techStack ?? this.techStack,
        keyDeliverables: keyDeliverables ?? this.keyDeliverables,
        badges: badges ?? this.badges,
        link: link ?? this.link,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        isVisible: isVisible ?? this.isVisible,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// 简历完整数据（由引擎拼装）
class ResumeData {
  final ResumeProfileEntity profile;
  final List<WorkExperienceEntity> workExperiences;
  final List<EducationEntity> educations;
  final List<SkillItemEntity> skills;
  final List<ProjectExperienceEntity> projects;

  const ResumeData({
    required this.profile,
    this.workExperiences = const [],
    this.educations = const [],
    this.skills = const [],
    this.projects = const [],
  });
}
