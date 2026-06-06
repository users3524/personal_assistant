/// 简历仓库实现。
library;

import 'package:riverpod/riverpod.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/resume_entity.dart';
import '../../domain/repositories/resume_repository.dart';
import '../datasources/resume_dao.dart';

class ResumeRepositoryImpl implements ResumeRepository {
  final ResumeDao _dao;

  ResumeRepositoryImpl(this._dao);

  @override
  Future<ResumeProfileEntity?> getProfile() => _dao.getProfile();

  @override
  Future<void> saveProfile(ResumeProfileEntity profile) =>
      _dao.saveProfile(profile);

  @override
  Future<List<WorkExperienceEntity>> getWorkExperiences() =>
      _dao.getWorkExperiences();

  @override
  Future<List<WorkExperienceEntity>> getVisibleWorkExperiences() =>
      _dao.getVisibleWorkExperiences();

  @override
  Future<WorkExperienceEntity> saveWorkExperience(
    WorkExperienceEntity exp,
  ) =>
      _dao.saveWorkExperience(exp);

  @override
  Future<void> deleteWorkExperience(int id) =>
      _dao.deleteWorkExperience(id);

  @override
  Future<void> reorderWorkExperiences(List<int> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final exp = await _dao.getWorkExperiences();
      final target = exp.where((e) => e.id == ids[i]).firstOrNull;
      if (target != null) {
        await _dao.saveWorkExperience(target.copyWith(sortOrder: i));
      }
    }
  }

  @override
  Future<List<EducationEntity>> getEducations() => _dao.getEducations();

  @override
  Future<List<EducationEntity>> getVisibleEducations() =>
      _dao.getVisibleEducations();

  @override
  Future<EducationEntity> saveEducation(EducationEntity edu) =>
      _dao.saveEducation(edu);

  @override
  Future<void> deleteEducation(int id) => _dao.deleteEducation(id);

  @override
  Future<List<SkillItemEntity>> getSkills() => _dao.getSkills();

  @override
  Future<List<SkillItemEntity>> getVisibleSkills() =>
      _dao.getVisibleSkills();

  @override
  Future<SkillItemEntity> saveSkill(SkillItemEntity skill) =>
      _dao.saveSkill(skill);

  @override
  Future<void> deleteSkill(int id) => _dao.deleteSkill(id);

  @override
  Future<List<ProjectExperienceEntity>> getProjects() =>
      _dao.getProjects();

  @override
  Future<List<ProjectExperienceEntity>> getVisibleProjects() =>
      _dao.getVisibleProjects();

  @override
  Future<ProjectExperienceEntity> saveProject(
    ProjectExperienceEntity proj,
  ) =>
      _dao.saveProject(proj);

  @override
  Future<void> deleteProject(int id) => _dao.deleteProject(id);

  @override
  Future<ResumeData> buildResumeData() async {
    final profile = await getProfile();
    return ResumeData(
      profile: profile ??
          ResumeProfileEntity(
            fullName: '',
            updatedAt: DateTime(2000),
          ),
      workExperiences: await getVisibleWorkExperiences(),
      educations: await getVisibleEducations(),
      skills: await getVisibleSkills(),
      projects: await getVisibleProjects(),
    );
  }
}

// ===== Providers =====

final resumeDaoProvider = FutureProvider<ResumeDao>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ResumeDao(db);
});

final resumeRepositoryProvider =
    FutureProvider<ResumeRepository>((ref) async {
  final dao = await ref.watch(resumeDaoProvider.future);
  return ResumeRepositoryImpl(dao);
});
