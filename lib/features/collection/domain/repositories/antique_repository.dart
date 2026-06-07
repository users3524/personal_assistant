/// 文玩模块仓库接口。
library;

import '../entities/antique_entity.dart';

abstract class AntiqueRepository {
  // ===== 藏品 CRUD =====
  Future<AntiqueEntity> create(AntiqueEntity item);
  Future<AntiqueEntity?> getById(int id);
  Future<List<AntiqueEntity>> getAll();
  Future<AntiqueEntity> update(AntiqueEntity item);
  Future<void> delete(int id);

  // ===== 查询筛选 =====
  Future<List<AntiqueEntity>> getByCategory(String category);
  Future<List<AntiqueEntity>> getByCondition(AntiqueCondition condition);
  Future<List<AntiqueEntity>> getByYearRange(int startYear, int endYear);
  Future<List<AntiqueEntity>> search(String keyword);

  // ===== 估值记录 =====
  Future<List<ValuationRecordEntity>> getValuations(int itemId);
  Future<ValuationRecordEntity> addValuation(ValuationRecordEntity record);

  // ===== 盘玩日志 =====
  Future<List<PattingLogEntity>> getPattingLogs(int itemId);
  Future<List<PattingLogEntity>> getPattingLogsByDate(DateTime date);
  Future<PattingLogEntity> addPattingLog(PattingLogEntity log);

  // ===== 统计 =====
  Future<Map<String, int>> countByCategory();
  Future<double> totalValuation();

  // ===== 批量查询 =====
  /// 返回 Map<itemId, 最新一张打卡照片路径>
  Future<Map<int, String>> getLatestPattingPhotos();
}
