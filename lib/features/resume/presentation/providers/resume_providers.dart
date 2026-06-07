/// 简历模块状态管理 Provider。
library;

export '../../data/repositories/resume_repository_impl.dart'
    show resumeRepositoryProvider, resumeRefreshProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/resume_repository_impl.dart';
import '../../domain/entities/resume_entity.dart';

/// 简历刷新触发器（每次保存后自增）
final resumeRefreshTriggerProvider = StateProvider<int>((ref) => 0);

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
