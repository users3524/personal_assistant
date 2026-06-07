/// 简历模块 DAO — drift 数据库操作。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/resume_entity.dart';

class ResumeDao {
  final AppDatabase _db;

  ResumeDao(this._db);

  // ===== 个人资料 =====

  ResumeProfileEntity _profileToEntity(ResumeProfileData row) =>
      ResumeProfileEntity(
        id: row.id,
        fullName: row.fullName,
        avatarPath: row.avatarPath,
        email: row.email,
        phone: row.phone,
        personalSummary: row.personalSummary,
        website: row.website,
        location: row.location,
        jobTitle: row.jobTitle,
        updatedAt: row.updatedAt,
      );

  ResumeProfileCompanion _profileToCompanion(ResumeProfileEntity e) =>
      ResumeProfileCompanion(
        fullName: Value(e.fullName),
        avatarPath: Value(e.avatarPath),
        email: Value(e.email),
        phone: Value(e.phone),
        personalSummary: Value(e.personalSummary),
        website: Value(e.website),
        location: Value(e.location),
        jobTitle: Value(e.jobTitle),
      );

  Future<ResumeProfileEntity?> getProfile() async {
    final rows = await _db.select(_db.resumeProfile).get();
    if (rows.isEmpty) return null;
    return _profileToEntity(rows.first);
  }

  Future<void> saveProfile(ResumeProfileEntity entity) async {
    final existing = await getProfile();
    if (existing != null) {
      await (_db.update(_db.resumeProfile)
            ..where((t) => t.id.equals(existing.id!)))
          .write(_profileToCompanion(entity).copyWith(
            updatedAt: Value(DateTime.now()),
          ));
    } else {
      await _db.into(_db.resumeProfile).insert(_profileToCompanion(entity));
    }
  }

  // ===== 工作经历 =====

  WorkExperienceEntity _workToEntity(WorkExperience row) =>
      WorkExperienceEntity(
        id: row.id,
        company: row.company,
        position: row.position,
        startDate: row.startDate,
        endDate: row.endDate,
        description: row.description,
        techStack: row.techStack,
        isVisible: row.isVisible,
        sortOrder: row.sortOrder,
      );

  WorkExperiencesCompanion _workToCompanion(WorkExperienceEntity e) =>
      WorkExperiencesCompanion(
        company: Value<String>(e.company),
        position: Value<String>(e.position),
        startDate: Value<DateTime>(e.startDate),
        endDate: Value<DateTime?>(e.endDate),
        description: Value<String>(e.description ?? ''),
        techStack: Value<List<String>>(e.techStack.toList()),
        isVisible: Value<bool>(e.isVisible),
        sortOrder: Value<int>(e.sortOrder),
      );

  Future<List<WorkExperienceEntity>> getWorkExperiences() async {
    final rows = await (_db.select(_db.workExperiences)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_workToEntity).toList();
  }

  Future<List<WorkExperienceEntity>> getVisibleWorkExperiences() async {
    final rows = await (_db.select(_db.workExperiences)
          ..where((t) => t.isVisible.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_workToEntity).toList();
  }

  Future<WorkExperienceEntity> saveWorkExperience(
    WorkExperienceEntity entity,
  ) async {
    if (entity.id != null) {
      await (_db.update(_db.workExperiences)
            ..where((t) => t.id.equals(entity.id!)))
          .write(_workToCompanion(entity));
      return entity;
    }
    final id = await _db.into(_db.workExperiences).insert(
          _workToCompanion(entity),
        );
    return entity.copyWith(id: id);
  }

  Future<void> deleteWorkExperience(int id) async {
    await (_db.delete(_db.workExperiences)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // ===== 教育经历 =====

  EducationEntity _eduToEntity(Education row) => EducationEntity(
        id: row.id,
        school: row.school,
        major: row.major,
        degree: row.degree,
        startDate: row.startDate,
        endDate: row.endDate,
        description: row.description,
        isVisible: row.isVisible,
        sortOrder: row.sortOrder,
      );

  EducationsCompanion _eduToCompanion(EducationEntity e) =>
      EducationsCompanion(
        school: Value(e.school),
        major: Value(e.major),
        degree: Value(e.degree),
        startDate: Value(e.startDate),
        endDate: Value(e.endDate),
        description: Value(e.description),
        isVisible: Value(e.isVisible),
        sortOrder: Value(e.sortOrder),
      );

  Future<List<EducationEntity>> getEducations() async {
    final rows = await (_db.select(_db.educations)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_eduToEntity).toList();
  }

  Future<List<EducationEntity>> getVisibleEducations() async {
    final rows = await (_db.select(_db.educations)
          ..where((t) => t.isVisible.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_eduToEntity).toList();
  }

  Future<EducationEntity> saveEducation(EducationEntity entity) async {
    if (entity.id != null) {
      await (_db.update(_db.educations)
            ..where((t) => t.id.equals(entity.id!)))
          .write(_eduToCompanion(entity));
      return entity;
    }
    final id = await _db.into(_db.educations).insert(_eduToCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<void> deleteEducation(int id) async {
    await (_db.delete(_db.educations)..where((t) => t.id.equals(id))).go();
  }

  // ===== 技能 =====

  SkillItemEntity _skillToEntity(SkillItem row) => SkillItemEntity(
        id: row.id,
        name: row.name,
        category: row.category,
        proficiency: row.proficiency,
        isVisible: row.isVisible,
        sortOrder: row.sortOrder,
      );

  SkillItemsCompanion _skillToCompanion(SkillItemEntity e) =>
      SkillItemsCompanion(
        name: Value(e.name),
        category: Value(e.category),
        proficiency: Value(e.proficiency),
        isVisible: Value(e.isVisible),
        sortOrder: Value(e.sortOrder),
      );

  Future<List<SkillItemEntity>> getSkills() async {
    final rows = await (_db.select(_db.skillItems)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_skillToEntity).toList();
  }

  Future<List<SkillItemEntity>> getVisibleSkills() async {
    final rows = await (_db.select(_db.skillItems)
          ..where((t) => t.isVisible.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_skillToEntity).toList();
  }

  Future<SkillItemEntity> saveSkill(SkillItemEntity entity) async {
    if (entity.id != null) {
      await (_db.update(_db.skillItems)
            ..where((t) => t.id.equals(entity.id!)))
          .write(_skillToCompanion(entity));
      return entity;
    }
    final id = await _db.into(_db.skillItems).insert(_skillToCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<void> deleteSkill(int id) async {
    await (_db.delete(_db.skillItems)..where((t) => t.id.equals(id))).go();
  }

  // ===== 项目经历 =====

  ProjectExperienceEntity _projectToEntity(ProjectExperience row) =>
      ProjectExperienceEntity(
        id: row.id,
        name: row.name,
        role: row.role,
        description: row.description,
        techStack: row.techStack,
        link: row.link,
        startDate: row.startDate,
        endDate: row.endDate,
        isVisible: row.isVisible,
        sortOrder: row.sortOrder,
      );

  ProjectExperiencesCompanion _projectToCompanion(
    ProjectExperienceEntity e,
  ) =>
      ProjectExperiencesCompanion(
        name: Value<String>(e.name),
        role: Value<String>(e.role ?? ''),
        description: Value<String>(e.description ?? ''),
        techStack: Value<List<String>>(e.techStack.toList()),
        link: Value<String?>(e.link ?? ''),
        startDate: Value<DateTime>(e.startDate),
        endDate: Value<DateTime?>(e.endDate),
        isVisible: Value(e.isVisible),
        sortOrder: Value(e.sortOrder),
      );

  Future<List<ProjectExperienceEntity>> getProjects() async {
    final rows = await (_db.select(_db.projectExperiences)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_projectToEntity).toList();
  }

  Future<List<ProjectExperienceEntity>> getVisibleProjects() async {
    final rows = await (_db.select(_db.projectExperiences)
          ..where((t) => t.isVisible.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(_projectToEntity).toList();
  }

  Future<ProjectExperienceEntity> saveProject(
    ProjectExperienceEntity entity,
  ) async {
    if (entity.id != null) {
      await (_db.update(_db.projectExperiences)
            ..where((t) => t.id.equals(entity.id!)))
          .write(_projectToCompanion(entity));
      return entity;
    }
    final id = await _db.into(_db.projectExperiences).insert(
          _projectToCompanion(entity),
        );
    return entity.copyWith(id: id);
  }

  Future<void> deleteProject(int id) async {
    await (_db.delete(_db.projectExperiences)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  // ===== 辅助 =====

  List<String> _decodeList(String json) {
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  String _encodeList(List<String> list) => jsonEncode(list);
}
