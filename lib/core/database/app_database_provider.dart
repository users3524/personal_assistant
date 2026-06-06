/// 应用数据库 Provider。
///
/// 数据库初始化是异步操作，使用 FutureProvider 管理。
/// 下游 provider 通过 ref.watch 获取数据库实例。
library;

import 'package:riverpod/riverpod.dart';

import 'app_database.dart';

/// 异步数据库 Provider（首次 watch 时自动初始化）
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await AppDatabase.create();
  // 当 ref 被销毁时关闭数据库连接
  ref.onDispose(() => db.close());
  return db;
});
