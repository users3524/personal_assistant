import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/iso_week.dart';

void main() {
  group('IsoWeek', () {
    test('maps calendar year boundaries to the correct ISO week year', () {
      expect(IsoWeek.fromDate(DateTime(2021, 1, 1)).year, 2020);
      expect(IsoWeek.fromDate(DateTime(2021, 1, 1)).weekNumber, 53);
      expect(IsoWeek.fromDate(DateTime(2021, 1, 4)).year, 2021);
      expect(IsoWeek.fromDate(DateTime(2021, 1, 4)).weekNumber, 1);
      expect(IsoWeek.fromDate(DateTime(2020, 12, 31)).year, 2020);
      expect(IsoWeek.fromDate(DateTime(2020, 12, 31)).weekNumber, 53);
    });

    test('calculates start date from ISO year and week number', () {
      expect(IsoWeek.startDateOf(2020, 53), DateTime(2020, 12, 28));
      expect(IsoWeek.startDateOf(2021, 1), DateTime(2021, 1, 4));
    });

    test('rejects a week number that the ISO year does not contain', () {
      expect(() => IsoWeek.startDateOf(2021, 53), throwsArgumentError);
    });
  });
}
