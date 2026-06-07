/// 文玩模块 DAO — drift 数据库操作。
library;

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/antique_entity.dart';

class AntiqueDao {
  final AppDatabase _db;

  AntiqueDao(this._db);

  // ===== 转换器 =====

  AntiqueEntity _toEntity(AntiqueItemRow row) {
    return AntiqueEntity(
      id: row.id,
      name: row.name,
      category: row.category,
      subtype: row.subtype,
      description: row.description,
      acquiredDate: row.acquiredDate,
      acquiredPrice: row.acquiredPrice,
      sourceSeller: row.sourceSeller,
      condition: _conditionFromString(row.condition),
      currentValuation: row.currentValuation,
      imagePaths: row.imagePaths,
      fingerprints: row.fingerprints,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  AntiqueItemsCompanion _toCompanion(AntiqueEntity entity) {
    return AntiqueItemsCompanion(
      name: Value(entity.name),
      category: Value(entity.category),
      subtype: Value(entity.subtype),
      description: Value(entity.description),
      acquiredDate: Value(entity.acquiredDate),
      acquiredPrice: Value(entity.acquiredPrice),
      sourceSeller: Value(entity.sourceSeller),
      condition: Value(_conditionToString(entity.condition)),
      currentValuation: Value(entity.currentValuation),
      imagePaths: Value(entity.imagePaths),
      fingerprints: Value(entity.fingerprints),
      notes: Value(entity.notes),
    );
  }

  String _conditionToString(AntiqueCondition c) {
    switch (c) {
      case AntiqueCondition.perfect:
        return 'perfect';
      case AntiqueCondition.good:
        return 'good';
      case AntiqueCondition.fair:
        return 'fair';
      case AntiqueCondition.poor:
        return 'poor';
    }
  }

  AntiqueCondition _conditionFromString(String s) {
    switch (s) {
      case 'perfect':
        return AntiqueCondition.perfect;
      case 'good':
        return AntiqueCondition.good;
      case 'fair':
        return AntiqueCondition.fair;
      case 'poor':
        return AntiqueCondition.poor;
      default:
        return AntiqueCondition.good;
    }
  }

  ValuationRecordEntity _valuationToEntity(ValuationRecordRow row) {
    return ValuationRecordEntity(
      id: row.id,
      itemId: row.itemId,
      date: row.date,
      amount: row.amount,
      remark: row.remark,
    );
  }

  PattingLogEntity _pattingToEntity(PattingLogRow row) {
    return PattingLogEntity(
      id: row.id,
      itemId: row.itemId,
      date: row.date,
      durationMinutes: row.durationMinutes,
      method: row.method,
      note: row.note,
      photoPaths: row.photoPaths,
    );
  }

  // ===== 藏品 CRUD =====

  Future<AntiqueEntity> insert(AntiqueEntity entity) async {
    final id = await _db.into(_db.antiqueItems).insert(_toCompanion(entity));
    return entity.copyWith(id: id);
  }

  Future<AntiqueEntity?> getById(int id) async {
    final row = await (_db.select(_db.antiqueItems)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _toEntity(row) : null;
  }

  Future<List<AntiqueEntity>> getAll() async {
    final rows = await (_db.select(_db.antiqueItems)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<AntiqueEntity> update(AntiqueEntity entity) async {
    await (_db.update(_db.antiqueItems)
          ..where((t) => t.id.equals(entity.id!)))
        .write(_toCompanion(entity).copyWith(
          updatedAt: Value(DateTime.now()),
        ));
    return entity;
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.antiqueItems)..where((t) => t.id.equals(id))).go();
  }

  // ===== 查询筛选 =====

  Future<List<AntiqueEntity>> getByCategory(String category) async {
    final rows = await (_db.select(_db.antiqueItems)
          ..where((t) => t.category.equals(category))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<AntiqueEntity>> getByCondition(AntiqueCondition condition) async {
    final condStr = _conditionToString(condition);
    final rows = await (_db.select(_db.antiqueItems)
          ..where((t) => t.condition.equals(condStr))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<AntiqueEntity>> getByYearRange(
    int startYear,
    int endYear,
  ) async {
    final start = DateTime(startYear, 1, 1);
    final end = DateTime(endYear, 12, 31);
    final rows = await (_db.select(_db.antiqueItems)
          ..where((t) =>
              t.acquiredDate.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.acquiredDate)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<AntiqueEntity>> search(String keyword) async {
    final pattern = '%$keyword%';
    final rows = await (_db.select(_db.antiqueItems)
          ..where((t) =>
              t.name.like(pattern) | t.description.like(pattern) |
              t.category.like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows.map(_toEntity).toList();
  }

  // ===== 估值记录 =====

  Future<List<ValuationRecordEntity>> getValuations(int itemId) async {
    final rows = await (_db.select(_db.valuationRecords)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_valuationToEntity).toList();
  }

  Future<ValuationRecordEntity> addValuation(
    ValuationRecordEntity record,
  ) async {
    final id = await _db.into(_db.valuationRecords).insert(
          ValuationRecordsCompanion(
            itemId: Value(record.itemId),
            date: Value(record.date),
            amount: Value(record.amount),
            remark: Value(record.remark),
          ),
        );
    return ValuationRecordEntity(
      id: id,
      itemId: record.itemId,
      date: record.date,
      amount: record.amount,
      remark: record.remark,
    );
  }

  // ===== 盘玩日志 =====

  Future<List<PattingLogEntity>> getPattingLogs(int itemId) async {
    final rows = await (_db.select(_db.pattingLogs)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_pattingToEntity).toList();
  }

  Future<List<PattingLogEntity>> getPattingLogsByDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows = await (_db.select(_db.pattingLogs)
          ..where((t) => t.date.isBetweenValues(dayStart, dayEnd))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_pattingToEntity).toList();
  }

  Future<PattingLogEntity> addPattingLog(PattingLogEntity log) async {
    final id = await _db.into(_db.pattingLogs).insert(
          PattingLogsCompanion(
            itemId: Value(log.itemId),
            date: Value(log.date),
            durationMinutes: Value(log.durationMinutes),
            method: Value(log.method),
            note: Value(log.note),
            photoPaths: Value(log.photoPaths),
          ),
        );
    return PattingLogEntity(
      id: id,
      itemId: log.itemId,
      date: log.date,
      durationMinutes: log.durationMinutes,
      method: log.method,
      note: log.note,
      photoPaths: log.photoPaths,
    );
  }

  // ===== 统计 =====

  Future<Map<String, int>> countByCategory() async {
    final rows = await _db.select(_db.antiqueItems).get();
    final map = <String, int>{};
    for (final row in rows) {
      map[row.category] = (map[row.category] ?? 0) + 1;
    }
    return map;
  }

  Future<double> totalValuation() async {
    final rows = await _db.select(_db.antiqueItems).get();
    return rows.fold<double>(
      0,
      (sum, r) => sum + (r.currentValuation ?? 0),
    );
  }
}
