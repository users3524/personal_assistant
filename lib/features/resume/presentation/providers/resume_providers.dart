/// 简历模块状态管理 Provider。
library;

export '../../data/repositories/resume_repository_impl.dart'
    show resumeRepositoryProvider, resumeRefreshProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/resume_repository_impl.dart';
import '../../domain/entities/resume_entity.dart';

/// 简历数据（监听刷新触发器）
final resumeDataProvider = FutureProvider<ResumeData>((ref) {
  ref.watch(resumeRefreshProvider);
  return ref.watch(resumeRepositoryProvider.future).then((repo) {
    return repo.buildResumeData();
  });
});

/// 选中的简历模板 ID
final selectedTemplateIdProvider = StateProvider<int>((ref) => 0);

/// 个人资料（监听刷新触发器）
final resumeProfileProvider = FutureProvider<ResumeProfileEntity?>((ref) {
  ref.watch(resumeRefreshProvider);
  return ref.watch(resumeRepositoryProvider.future).then((repo) {
    return repo.getProfile();
  });
});

/// 技能分类聚合：自动按 category 分组并按 proficiency 排序
final sortedSkillsProvider = FutureProvider<Map<String, List<SkillItemEntity>>>((ref) async {
  final resumeData = await ref.watch(resumeDataProvider.future);
  final activeSkills = resumeData.skills.where((s) => s.isVisible).toList();
  final grouped = <String, List<SkillItemEntity>>{};
  for (final skill in activeSkills) {
    grouped.putIfAbsent(skill.category, () => []).add(skill);
  }
  for (final key in grouped.keys) {
    grouped[key]!.sort((a, b) => b.proficiency.compareTo(a.proficiency));
  }
  return grouped;
});
