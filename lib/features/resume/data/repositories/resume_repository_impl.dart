/// 简历仓库实现。
library;

import 'package:riverpod/riverpod.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/resume_entity.dart';
import '../../domain/repositories/resume_repository.dart';
import '../datasources/resume_dao.dart';

class ResumeRepositoryImpl implements ResumeRepository {
  final ResumeDao _dao;
  final void Function()? _onChanged;

  ResumeRepositoryImpl(this._dao, [this._onChanged]);

  void _notify() => _onChanged?.call();

  @override
  Future<ResumeProfileEntity?> getProfile() => _dao.getProfile();

  @override
  Future<void> saveProfile(ResumeProfileEntity profile) async {
    await _dao.saveProfile(profile);
    _notify();
  }

  @override
  Future<List<WorkExperienceEntity>> getWorkExperiences() =>
      _dao.getWorkExperiences();

  @override
  Future<List<WorkExperienceEntity>> getVisibleWorkExperiences() =>
      _dao.getVisibleWorkExperiences();

  @override
  Future<WorkExperienceEntity> saveWorkExperience(WorkExperienceEntity exp) async {
    final result = await _dao.saveWorkExperience(exp);
    _notify();
    return result;
  }

  @override
  Future<void> deleteWorkExperience(int id) async {
    await _dao.deleteWorkExperience(id);
    _notify();
  }

  @override
  Future<void> reorderWorkExperiences(List<int> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final exp = await _dao.getWorkExperiences();
      final target = exp.where((e) => e.id == ids[i]).firstOrNull;
      if (target != null) {
        await _dao.saveWorkExperience(target.copyWith(sortOrder: i));
      }
    }
    _notify();
  }

  @override
  Future<List<EducationEntity>> getEducations() => _dao.getEducations();

  @override
  Future<List<EducationEntity>> getVisibleEducations() =>
      _dao.getVisibleEducations();

  @override
  Future<EducationEntity> saveEducation(EducationEntity edu) async {
    final result = await _dao.saveEducation(edu);
    _notify();
    return result;
  }

  @override
  Future<void> deleteEducation(int id) async {
    await _dao.deleteEducation(id);
    _notify();
  }

  @override
  Future<List<SkillItemEntity>> getSkills() => _dao.getSkills();

  @override
  Future<List<SkillItemEntity>> getVisibleSkills() =>
      _dao.getVisibleSkills();

  @override
  Future<SkillItemEntity> saveSkill(SkillItemEntity skill) async {
    final result = await _dao.saveSkill(skill);
    _notify();
    return result;
  }

  @override
  Future<void> deleteSkill(int id) async {
    await _dao.deleteSkill(id);
    _notify();
  }

  @override
  Future<List<ProjectExperienceEntity>> getProjects() =>
      _dao.getProjects();

  @override
  Future<List<ProjectExperienceEntity>> getVisibleProjects() =>
      _dao.getVisibleProjects();

  @override
  Future<ProjectExperienceEntity> saveProject(ProjectExperienceEntity proj) async {
    final result = await _dao.saveProject(proj);
    _notify();
    return result;
  }

  @override
  Future<void> deleteProject(int id) async {
    await _dao.deleteProject(id);
    _notify();
  }

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
  // 每次写操作后自动触发刷新
  return ResumeRepositoryImpl(dao, () {
    ref.read(resumeRefreshProvider.notifier).state++;
  });
});

/// 简历数据刷新通知（自增计数器，每次保存后触发）
final resumeRefreshProvider = StateProvider<int>((ref) => 0);
