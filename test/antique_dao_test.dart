import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/collection/data/datasources/antique_dao.dart';
import 'package:personal_assistant/features/collection/domain/entities/antique_entity.dart';

void main() {
  group('AntiqueDao', () {
    late AppDatabase db;
    late AntiqueDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = AntiqueDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('sums patting minutes for the target local day only', () async {
      final item = await dao.insert(_antique());
      final itemId = item.id!;

      await dao.addPattingLog(_log(itemId, DateTime(2026, 6, 19, 23, 59), 5));
      await dao.addPattingLog(_log(itemId, DateTime(2026, 6, 20), 10));
      await dao.addPattingLog(
        _log(itemId, DateTime(2026, 6, 20, 23, 59, 59), 25),
      );
      await dao.addPattingLog(_log(itemId, DateTime(2026, 6, 21), 60));

      final total = await dao.sumPattingMinutesByDate(DateTime(2026, 6, 20));

      expect(total, 35);
    });

    test('date and month queries use half-open ranges', () async {
      final item = await dao.insert(_antique());
      final itemId = item.id!;

      await dao.addPattingLog(_log(itemId, DateTime(2026, 6, 30, 23, 59), 30));
      await dao.addPattingLog(_log(itemId, DateTime(2026, 7), 45));

      final dayLogs = await dao.getPattingLogsByDate(DateTime(2026, 6, 30));
      final monthLogs = await dao.getPattingLogsByMonth(2026, 6);

      expect(dayLogs.map((log) => log.durationMinutes), [30]);
      expect(monthLogs.map((log) => log.durationMinutes), [30]);
    });
  });
}

AntiqueEntity _antique() {
  final now = DateTime(2026, 6, 20, 9);
  return AntiqueEntity(
    name: 'Walnut',
    category: 'walnut',
    acquiredDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

PattingLogEntity _log(int itemId, DateTime date, int durationMinutes) {
  return PattingLogEntity(
    itemId: itemId,
    date: date,
    durationMinutes: durationMinutes,
  );
}
