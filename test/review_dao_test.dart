import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:personal_assistant/core/database/app_database.dart';
import 'package:personal_assistant/features/ai_assistant/data/datasources/review_dao.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/review_entity.dart';

void main() {
  group('ReviewDao', () {
    late AppDatabase db;
    late ReviewDao dao;

    setUp(() {
      db = AppDatabase.createInMemory();
      dao = ReviewDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'gets daily reviews by ISO week date range across calendar years',
      () async {
        await dao.insertDaily(_daily(DateTime(2020, 12, 27), 'Previous week'));
        await dao.insertDaily(_daily(DateTime(2020, 12, 28), 'Week start'));
        await dao.insertDaily(_daily(DateTime(2021, 1, 1), 'New year'));
        await dao.insertDaily(_daily(DateTime(2021, 1, 3, 23, 59), 'Week end'));
        await dao.insertDaily(_daily(DateTime(2021, 1, 4), 'Next week'));

        final reviews = await dao.getDailyByWeek(2020, 53);

        expect(reviews.map((review) => review.summary), [
          'Week start',
          'New year',
          'Week end',
        ]);
      },
    );

    test('month and range queries use half-open ranges', () async {
      await dao.insertDaily(_daily(DateTime(2026, 6, 30, 23, 59), 'June'));
      await dao.insertDaily(_daily(DateTime(2026, 7), 'July'));

      final monthReviews = await dao.getDailyByMonth(2026, 6);
      final rangeCount = await dao.countDailyInRange(
        DateTime(2026, 6, 1),
        DateTime(2026, 7, 1),
      );

      expect(monthReviews.map((review) => review.summary), ['June']);
      expect(rangeCount, 1);
    });

    test('persists daily review calibration flag', () async {
      await dao.insertDaily(
        _daily(
          DateTime(2026, 6, 21),
          'Malformed AI output',
          calibrationRequired: true,
        ),
      );

      final daily = await dao.getDailyByDate(DateTime(2026, 6, 21));

      expect(daily?.calibrationRequired, true);
    });

    test('marks existing daily review as calibration required', () async {
      await dao.insertDaily(_daily(DateTime(2026, 6, 21), 'Normal day'));

      await dao.markDailyCalibrationRequired(
        DateTime(2026, 6, 21),
        now: DateTime(2026, 6, 22, 3),
      );

      final daily = await dao.getDailyByDate(DateTime(2026, 6, 21));
      expect(daily?.summary, 'Normal day');
      expect(daily?.calibrationRequired, true);
      expect(daily?.updatedAt, DateTime(2026, 6, 22, 3));
    });

    test(
      'creates placeholder daily review when calibration is required',
      () async {
        await dao.markDailyCalibrationRequired(
          DateTime(2026, 6, 21, 15),
          now: DateTime(2026, 6, 22, 3),
        );

        final daily = await dao.getDailyByDate(DateTime(2026, 6, 21));
        expect(daily?.date, DateTime(2026, 6, 21));
        expect(daily?.summary, contains('深夜 AI 生成失败'));
        expect(daily?.calibrationRequired, true);
        expect(daily?.createdAt, DateTime(2026, 6, 22, 3));
      },
    );

    test('deleting daily review cleans milestone source relations', () async {
      final now = DateTime(2026, 6, 21, 9);
      final daily = await dao.insertDaily(_daily(now, 'Milestone source'));
      final other = await dao.insertDaily(
        _daily(DateTime(2026, 6, 22), 'Other source'),
      );
      final milestoneId = await _insertMilestone(db, now);
      await _insertMilestoneRelation(
        db,
        milestoneId: milestoneId,
        sourceType: 'daily_review',
        sourceId: daily.id!,
        now: now,
      );
      await _insertMilestoneRelation(
        db,
        milestoneId: milestoneId,
        sourceType: 'daily_review',
        sourceId: other.id!,
        now: now,
      );

      await dao.deleteDaily(DateTime(2026, 6, 21));

      final relations = await db.select(db.milestoneRelations).get();
      expect(relations.map((relation) => relation.sourceId), [other.id]);
      expect(await dao.getDailyByDate(DateTime(2026, 6, 21)), null);
      expect(await dao.getDailyByDate(DateTime(2026, 6, 22)), isNotNull);
    });
  });
}

Future<int> _insertMilestone(AppDatabase db, DateTime now) {
  return db
      .into(db.milestones)
      .insert(
        MilestonesCompanion.insert(
          title: 'Linked review milestone',
          occurredAt: now,
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<int> _insertMilestoneRelation(
  AppDatabase db, {
  required int milestoneId,
  required String sourceType,
  required int sourceId,
  required DateTime now,
}) {
  return db
      .into(db.milestoneRelations)
      .insert(
        MilestoneRelationsCompanion.insert(
          milestoneId: milestoneId,
          sourceType: sourceType,
          sourceId: Value(sourceId),
          createdAt: Value(now),
        ),
      );
}

DailyReviewEntity _daily(
  DateTime date,
  String summary, {
  bool calibrationRequired = false,
}) {
  final normalized = DateTime(
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute,
    date.second,
  );
  return DailyReviewEntity(
    date: normalized,
    summary: summary,
    calibrationRequired: calibrationRequired,
    createdAt: normalized,
    updatedAt: normalized,
  );
}
