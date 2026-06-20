class IsoWeek {
  final int year;
  final int weekNumber;

  const IsoWeek({required this.year, required this.weekNumber});

  factory IsoWeek.fromDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final weekThursday = normalized.add(
      Duration(days: DateTime.thursday - normalized.weekday),
    );
    final isoYear = weekThursday.year;
    final firstThursday = _firstThursdayOfIsoYear(isoYear);
    final weekNumber = 1 + (weekThursday.difference(firstThursday).inDays ~/ 7);
    return IsoWeek(year: isoYear, weekNumber: weekNumber);
  }

  DateTime get startDate => startDateOf(year, weekNumber);

  DateTime get endDateExclusive => startDate.add(const Duration(days: 7));

  static DateTime startDateOf(int year, int weekNumber) {
    if (weekNumber < 1 || weekNumber > 53) {
      throw ArgumentError.value(weekNumber, 'weekNumber', 'Must be 1..53');
    }

    final firstThursday = _firstThursdayOfIsoYear(year);
    final targetThursday = firstThursday.add(
      Duration(days: (weekNumber - 1) * 7),
    );
    final start = targetThursday.subtract(
      Duration(days: targetThursday.weekday - DateTime.monday),
    );

    final actualWeek = IsoWeek.fromDate(start);
    if (actualWeek.year != year || actualWeek.weekNumber != weekNumber) {
      throw ArgumentError.value(
        weekNumber,
        'weekNumber',
        'ISO year $year does not contain this week',
      );
    }

    return start;
  }

  static DateTime _firstThursdayOfIsoYear(int year) {
    final jan4 = DateTime(year, DateTime.january, 4);
    return jan4.add(Duration(days: DateTime.thursday - jan4.weekday));
  }
}
