/// 文玩仓库实现。
library;

import 'package:riverpod/riverpod.dart';

import '../../../../core/database/app_database_provider.dart';
import '../../domain/entities/antique_entity.dart';
import '../../domain/repositories/antique_repository.dart';
import '../datasources/antique_dao.dart';

class AntiqueRepositoryImpl implements AntiqueRepository {
  final AntiqueDao _dao;

  AntiqueRepositoryImpl(this._dao);

  @override
  Future<AntiqueEntity> create(AntiqueEntity item) => _dao.insert(item);

  @override
  Future<AntiqueEntity?> getById(int id) => _dao.getById(id);

  @override
  Future<List<AntiqueEntity>> getAll() => _dao.getAll();

  @override
  Future<AntiqueEntity> update(AntiqueEntity item) => _dao.update(item);

  @override
  Future<void> delete(int id) => _dao.delete(id);

  @override
  Future<List<AntiqueEntity>> getByCategory(String category) =>
      _dao.getByCategory(category);

  @override
  Future<List<AntiqueEntity>> getByCondition(AntiqueCondition condition) =>
      _dao.getByCondition(condition);

  @override
  Future<List<AntiqueEntity>> getByYearRange(int start, int end) =>
      _dao.getByYearRange(start, end);

  @override
  Future<List<AntiqueEntity>> search(String keyword) => _dao.search(keyword);

  @override
  Future<List<PattingLogEntity>> getPattingLogs(int itemId) =>
      _dao.getPattingLogs(itemId);

  @override
  Future<List<PattingLogEntity>> getPattingLogsByDate(DateTime date) =>
      _dao.getPattingLogsByDate(date);

  @override
  Future<List<PattingLogEntity>> getPattingLogsByMonth(int year, int month) =>
      _dao.getPattingLogsByMonth(year, month);

  @override
  Future<PattingLogEntity> addPattingLog(PattingLogEntity log) =>
      _dao.addPattingLog(log);

  @override
  Future<PattingLogEntity> updatePattingLog(PattingLogEntity log) =>
      _dao.updatePattingLog(log);

  @override
  Future<void> deletePattingLog(int id) => _dao.deletePattingLog(id);

  @override
  Future<Map<int, String>> getLatestPattingPhotos() =>
      _dao.getLatestPattingPhotos();

  @override
  Future<Map<String, int>> countByCategory() => _dao.countByCategory();

  @override
  Future<int> sumPattingMinutesByDate(DateTime date) =>
      _dao.sumPattingMinutesByDate(date);

  @override
  Future<Map<int, int>> countPattingLogsByItem() =>
      _dao.countPattingLogsByItem();

  @override
  Future<Map<int, int>> countPattingLogsByItemInRange(
    DateTime start,
    DateTime end,
  ) => _dao.countPattingLogsByItemInRange(start, end);

  @override
  Future<Map<int, int>> sumPattingMinutesByItem() =>
      _dao.sumPattingMinutesByItem();

  @override
  Future<Map<int, DateTime>> latestPattingDateByItem() =>
      _dao.latestPattingDateByItem();

  @override
  Future<Map<int, int>> countNightPattingLogsByItem() =>
      _dao.countNightPattingLogsByItem();
}

// ===== Riverpod Providers =====

final antiqueDaoProvider = FutureProvider<AntiqueDao>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return AntiqueDao(db);
});

final antiqueRepositoryProvider = FutureProvider<AntiqueRepository>((
  ref,
) async {
  final dao = await ref.watch(antiqueDaoProvider.future);
  return AntiqueRepositoryImpl(dao);
});
