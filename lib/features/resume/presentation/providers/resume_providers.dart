/// 简历模块状态管理 Provider。
library;

export '../../data/repositories/resume_repository_impl.dart'
    show resumeRepositoryProvider;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/resume_repository_impl.dart';
import '../../domain/entities/resume_entity.dart';
import '../../domain/repositories/resume_repository.dart';

/// 简历数据（自动刷新）
final resumeDataProvider = FutureProvider<ResumeData>((ref) {
  return ref.watch(resumeRepositoryProvider.future).then((repo) {
    return repo.buildResumeData();
  });
});

/// 选中的简历模板 ID
final selectedTemplateIdProvider = StateProvider<int>((ref) => 0);

/// 个人资料
final resumeProfileProvider = FutureProvider<ResumeProfileEntity?>((ref) {
  return ref.watch(resumeRepositoryProvider.future).then((repo) {
    return repo.getProfile();
  });
});
