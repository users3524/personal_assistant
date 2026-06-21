import 'package:flutter_test/flutter_test.dart';
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
  });
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
