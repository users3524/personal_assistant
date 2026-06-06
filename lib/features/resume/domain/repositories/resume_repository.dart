/// 简历模块仓库接口。
library;

import '../entities/resume_entity.dart';

abstract class ResumeRepository {
  // ===== 个人资料 =====
  Future<ResumeProfileEntity?> getProfile();
  Future<void> saveProfile(ResumeProfileEntity profile);

  // ===== 工作经历 =====
  Future<List<WorkExperienceEntity>> getWorkExperiences();
  Future<List<WorkExperienceEntity>> getVisibleWorkExperiences();
  Future<WorkExperienceEntity> saveWorkExperience(WorkExperienceEntity exp);
  Future<void> deleteWorkExperience(int id);
  Future<void> reorderWorkExperiences(List<int> ids);

  // ===== 教育经历 =====
  Future<List<EducationEntity>> getEducations();
  Future<List<EducationEntity>> getVisibleEducations();
  Future<EducationEntity> saveEducation(EducationEntity edu);
  Future<void> deleteEducation(int id);

  // ===== 技能 =====
  Future<List<SkillItemEntity>> getSkills();
  Future<List<SkillItemEntity>> getVisibleSkills();
  Future<SkillItemEntity> saveSkill(SkillItemEntity skill);
  Future<void> deleteSkill(int id);

  // ===== 项目经历 =====
  Future<List<ProjectExperienceEntity>> getProjects();
  Future<List<ProjectExperienceEntity>> getVisibleProjects();
  Future<ProjectExperienceEntity> saveProject(ProjectExperienceEntity proj);
  Future<void> deleteProject(int id);

  // ===== 简历数据组装 =====
  Future<ResumeData> buildResumeData();
}
