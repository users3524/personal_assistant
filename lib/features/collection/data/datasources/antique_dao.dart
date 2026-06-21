/// 文玩模块 DAO — drift 数据库操作。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/antique_entity.dart';

class AntiqueDao {
  final AppDatabase _db;

  AntiqueDao(this._db);

  // ===== 转换器 =====

  AntiqueEntity _toEntity(AntiqueItem row) {
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
      imagePaths: row.imagePaths,
      categoryMetadata: _parseMetadata(row.categoryMetadata),
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
      currentValuation: const Value<double?>(null),
      imagePaths: Value(entity.imagePaths),
      categoryMetadata: Value(
        entity.categoryMetadata != null
            ? jsonEncode(entity.categoryMetadata)
            : null,
      ),
      fingerprints: Value(entity.fingerprints),
      notes: Value(entity.notes),
    );
  }

  Map<String, String>? _parseMetadata(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return null;
    }
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

  PattingLogEntity _pattingToEntity(PattingLog row) {
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
    final row = await (_db.select(
      _db.antiqueItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null ? _toEntity(row) : null;
  }

  Future<List<AntiqueEntity>> getAll() async {
    final rows = await (_db.select(
      _db.antiqueItems,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    return rows.map(_toEntity).toList();
  }

  Future<AntiqueEntity> update(AntiqueEntity entity) async {
    await (_db.update(_db.antiqueItems)..where((t) => t.id.equals(entity.id!)))
        .write(_toCompanion(entity).copyWith(updatedAt: Value(DateTime.now())));
    return entity;
  }

  Future<void> delete(int id) async {
    await _db.transaction(() async {
      final logIds = await _pattingLogIdsForItem(id);
      if (logIds.isNotEmpty) {
        await (_db.delete(_db.milestoneRelations)..where(
              (t) =>
                  t.sourceType.equals('patting_log') & t.sourceId.isIn(logIds),
            ))
            .go();
      }
      await (_db.delete(_db.antiqueItems)..where((t) => t.id.equals(id))).go();
    });
  }

  // ===== 查询筛选 =====

  Future<List<AntiqueEntity>> getByCategory(String category) async {
    final rows =
        await (_db.select(_db.antiqueItems)
              ..where((t) => t.category.equals(category))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<AntiqueEntity>> getByCondition(AntiqueCondition condition) async {
    final condStr = _conditionToString(condition);
    final rows =
        await (_db.select(_db.antiqueItems)
              ..where((t) => t.condition.equals(condStr))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<AntiqueEntity>> getByYearRange(int startYear, int endYear) async {
    final start = DateTime(startYear, 1, 1);
    final end = DateTime(endYear, 12, 31);
    final rows =
        await (_db.select(_db.antiqueItems)
              ..where((t) => t.acquiredDate.isBetweenValues(start, end))
              ..orderBy([(t) => OrderingTerm.desc(t.acquiredDate)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  Future<List<AntiqueEntity>> search(String keyword) async {
    final pattern = '%$keyword%';
    final rows =
        await (_db.select(_db.antiqueItems)
              ..where(
                (t) =>
                    t.name.like(pattern) |
                    t.description.like(pattern) |
                    t.category.like(pattern),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  // ===== 盘玩日志 =====

  Future<List<PattingLogEntity>> getPattingLogs(int itemId) async {
    final rows =
        await (_db.select(_db.pattingLogs)
              ..where((t) => t.itemId.equals(itemId))
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_pattingToEntity).toList();
  }

  Future<List<PattingLogEntity>> getPattingLogsByDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final rows =
        await (_db.select(_db.pattingLogs)
              ..where(
                (t) =>
                    t.date.isBiggerOrEqualValue(dayStart) &
                    t.date.isSmallerThanValue(dayEnd),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return rows.map(_pattingToEntity).toList();
  }

  Future<int> sumPattingMinutesByDate(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final totalMinutes = _db.pattingLogs.durationMinutes.sum();
    final row =
        await (_db.selectOnly(_db.pattingLogs)
              ..addColumns([totalMinutes])
              ..where(
                _db.pattingLogs.date.isBiggerOrEqualValue(dayStart) &
                    _db.pattingLogs.date.isSmallerThanValue(dayEnd),
              ))
            .getSingle();
    return row.read(totalMinutes) ?? 0;
  }

  Future<List<PattingLogEntity>> getPattingLogsByMonth(
    int year,
    int month,
  ) async {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 1);
    final rows =
        await (_db.select(_db.pattingLogs)
              ..where(
                (t) =>
                    t.date.isBiggerOrEqualValue(monthStart) &
                    t.date.isSmallerThanValue(monthEnd),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_pattingToEntity).toList();
  }

  Future<PattingLogEntity> addPattingLog(PattingLogEntity log) async {
    final id = await _db
        .into(_db.pattingLogs)
        .insert(
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

  /// 更新打卡记录（仅备注和照片路径）
  Future<PattingLogEntity> updatePattingLog(PattingLogEntity log) async {
    await (_db.update(
      _db.pattingLogs,
    )..where((t) => t.id.equals(log.id!))).write(
      PattingLogsCompanion(
        note: Value(log.note),
        photoPaths: Value(log.photoPaths),
      ),
    );
    return log;
  }

  /// 删除打卡记录
  Future<void> deletePattingLog(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.milestoneRelations)..where(
            (t) => t.sourceType.equals('patting_log') & t.sourceId.equals(id),
          ))
          .go();
      await (_db.delete(_db.pattingLogs)..where((t) => t.id.equals(id))).go();
    });
  }

  /// 批量获取每个藏品最新一条有照片的打卡记录的第一张图路径
  /// 返回 Map<itemId, photoPath> — 没有打卡照片的 item 不出现在结果中
  Future<Map<int, String>> getLatestPattingPhotos() async {
    final query = _db.select(_db.pattingLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    final allLogs = await query.get();
    final result = <int, String>{};
    for (final row in allLogs) {
      if (result.containsKey(row.itemId)) continue; // 已取到最新
      if (row.photoPaths.isNotEmpty) {
        result[row.itemId] = row.photoPaths.first;
      }
    }
    return result;
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

  Future<Map<int, int>> countPattingLogsByItem() async {
    final itemId = _db.pattingLogs.itemId;
    final count = itemId.count();
    final rows =
        await (_db.selectOnly(_db.pattingLogs)
              ..addColumns([itemId, count])
              ..groupBy([itemId]))
            .get();

    return {
      for (final row in rows)
        if (row.read(itemId) != null) row.read(itemId)!: row.read(count) ?? 0,
    };
  }

  Future<Map<int, int>> countPattingLogsByItemInRange(
    DateTime start,
    DateTime end,
  ) async {
    final itemId = _db.pattingLogs.itemId;
    final count = itemId.count();
    final rows =
        await (_db.selectOnly(_db.pattingLogs)
              ..addColumns([itemId, count])
              ..where(_dateInHalfOpenRange(_db.pattingLogs.date, start, end))
              ..groupBy([itemId]))
            .get();

    return {
      for (final row in rows)
        if (row.read(itemId) != null) row.read(itemId)!: row.read(count) ?? 0,
    };
  }

  Future<Map<int, int>> sumPattingMinutesByItem() async {
    final itemId = _db.pattingLogs.itemId;
    final totalMinutes = _db.pattingLogs.durationMinutes.sum();
    final rows =
        await (_db.selectOnly(_db.pattingLogs)
              ..addColumns([itemId, totalMinutes])
              ..groupBy([itemId]))
            .get();

    return {
      for (final row in rows)
        if (row.read(itemId) != null)
          row.read(itemId)!: row.read(totalMinutes) ?? 0,
    };
  }

  Future<Map<int, DateTime>> latestPattingDateByItem() async {
    final itemId = _db.pattingLogs.itemId;
    final latestDate = _db.pattingLogs.date.max();
    final rows =
        await (_db.selectOnly(_db.pattingLogs)
              ..addColumns([itemId, latestDate])
              ..groupBy([itemId]))
            .get();

    return {
      for (final row in rows)
        if (row.read(itemId) != null && row.read(latestDate) != null)
          row.read(itemId)!: row.read(latestDate)!,
    };
  }

  Future<Map<int, int>> countNightPattingLogsByItem() async {
    final rows = await _db.select(_db.pattingLogs).get();
    final result = <int, int>{};
    for (final row in rows) {
      final hour = row.date.hour;
      if (hour >= 23 || hour < 3) {
        result[row.itemId] = (result[row.itemId] ?? 0) + 1;
      }
    }
    return result;
  }

  Expression<bool> _dateInHalfOpenRange(
    DateTimeColumn column,
    DateTime start,
    DateTime end,
  ) {
    return column.isBiggerOrEqualValue(start) & column.isSmallerThanValue(end);
  }

  Future<List<int>> _pattingLogIdsForItem(int itemId) async {
    final rows = await (_db.select(
      _db.pattingLogs,
    )..where((t) => t.itemId.equals(itemId))).get();
    return rows.map((row) => row.id).toList();
  }
}
