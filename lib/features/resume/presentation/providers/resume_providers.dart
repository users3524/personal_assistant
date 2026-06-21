/// 简历模块状态管理 Provider。
library;

export '../../data/repositories/resume_repository_impl.dart'
    show resumeRepositoryProvider, resumeRefreshProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../../../core/database/user_preferences_dao.dart';
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
final selectedTemplateIdProvider =
    AsyncNotifierProvider<SelectedTemplateIdNotifier, int>(
      SelectedTemplateIdNotifier.new,
    );

class SelectedTemplateIdNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final db = await ref.watch(appDatabaseProvider.future);
    final dao = UserPreferencesDao(db);
    return dao.getResumeTemplateId();
  }

  Future<void> select(int templateId) async {
    state = AsyncValue.data(templateId);
    final db = await ref.read(appDatabaseProvider.future);
    final dao = UserPreferencesDao(db);
    await dao.setResumeTemplateId(templateId);
  }
}

/// 个人资料（监听刷新触发器）
final resumeProfileProvider = FutureProvider<ResumeProfileEntity?>((ref) {
  ref.watch(resumeRefreshProvider);
  return ref.watch(resumeRepositoryProvider.future).then((repo) {
    return repo.getProfile();
  });
});

/// 技能分类聚合：自动按 category 分组并按 proficiency 排序
final sortedSkillsProvider = FutureProvider<Map<String, List<SkillItemEntity>>>(
  (ref) async {
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
  },
);
