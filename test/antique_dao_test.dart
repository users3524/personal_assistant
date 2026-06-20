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

    test('aggregates patting log counts by item', () async {
      final first = await dao.insert(_antique(name: 'First'));
      final second = await dao.insert(_antique(name: 'Second'));

      await dao.addPattingLog(_log(first.id!, DateTime(2026, 6, 20), 10));
      await dao.addPattingLog(_log(first.id!, DateTime(2026, 6, 21), 20));
      await dao.addPattingLog(_log(second.id!, DateTime(2026, 6, 22), 30));

      final counts = await dao.countPattingLogsByItem();

      expect(counts, {first.id!: 2, second.id!: 1});
    });

    test('aggregates patting log counts by half-open date range', () async {
      final first = await dao.insert(_antique(name: 'First'));
      final second = await dao.insert(_antique(name: 'Second'));
      final start = DateTime(2026, 6, 20);
      final end = DateTime(2026, 6, 22);

      await dao.addPattingLog(
        _log(first.id!, start.subtract(const Duration(minutes: 1)), 5),
      );
      await dao.addPattingLog(_log(first.id!, start, 10));
      await dao.addPattingLog(_log(first.id!, DateTime(2026, 6, 21, 12), 20));
      await dao.addPattingLog(_log(first.id!, end, 30));
      await dao.addPattingLog(_log(second.id!, DateTime(2026, 6, 21), 40));

      final counts = await dao.countPattingLogsByItemInRange(start, end);

      expect(counts, {first.id!: 2, second.id!: 1});
    });

    test('aggregates total patting minutes by item', () async {
      final first = await dao.insert(_antique(name: 'First'));
      final second = await dao.insert(_antique(name: 'Second'));

      await dao.addPattingLog(_log(first.id!, DateTime(2026, 6, 20), 10));
      await dao.addPattingLog(_log(first.id!, DateTime(2026, 6, 21), 25));
      await dao.addPattingLog(_log(second.id!, DateTime(2026, 6, 22), 30));

      final minutes = await dao.sumPattingMinutesByItem();

      expect(minutes, {first.id!: 35, second.id!: 30});
    });

    test('finds latest patting date by item', () async {
      final first = await dao.insert(_antique(name: 'First'));
      final second = await dao.insert(_antique(name: 'Second'));
      final latest = DateTime(2026, 6, 22, 9);

      await dao.addPattingLog(_log(first.id!, DateTime(2026, 6, 20), 10));
      await dao.addPattingLog(_log(first.id!, latest, 20));
      await dao.addPattingLog(_log(second.id!, DateTime(2026, 6, 21), 30));

      final dates = await dao.latestPattingDateByItem();

      expect(dates[first.id!], latest);
      expect(dates[second.id!], DateTime(2026, 6, 21));
    });

    test(
      'counts night owl logs from 23:00 inclusive to 03:00 exclusive',
      () async {
        final item = await dao.insert(_antique());
        final itemId = item.id!;

        await dao.addPattingLog(
          _log(itemId, DateTime(2026, 6, 20, 22, 59), 10),
        );
        await dao.addPattingLog(_log(itemId, DateTime(2026, 6, 20, 23), 10));
        await dao.addPattingLog(_log(itemId, DateTime(2026, 6, 21, 2, 59), 10));
        await dao.addPattingLog(_log(itemId, DateTime(2026, 6, 21, 3), 10));

        final counts = await dao.countNightPattingLogsByItem();

        expect(counts, {itemId: 2});
      },
    );
  });
}

AntiqueEntity _antique({String name = 'Walnut'}) {
  final now = DateTime(2026, 6, 20, 9);
  return AntiqueEntity(
    name: name,
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
