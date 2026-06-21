/// Central route names and path helpers.
library;

class RouteNames {
  RouteNames._();

  static const String mainShell = '/';
  static const String dashboard = '/today';

  static const String todoList = '/todos';
  static const String todoNew = '/todos/new';
  static const String todoDetail = '/todos/:id';
  static const String todoEdit = '/todos/:id/edit';

  static const String collectionList = '/collection';
  static const String collectionNew = '/collection/new';
  static const String collectionDetail = '/collection/:id';
  static const String collectionEdit = '/collection/:id/edit';

  static const String reviewHome = '/review';
  static const String dailyReviewNew = '/review/daily/new';
  static const String dailyReviewDetail = '/review/daily/:date';
  static const String dailyReviewEdit = '/review/daily/edit/:date';
  static const String weeklyReportDetail = '/review/weekly/:id';

  static const String resumeHome = '/resume';
  static const String resumePreview = '/resume/preview';
  static const String resumeTemplates = '/resume/templates';

  static const String settings = '/settings';

  static String todoDetailPath(int id) => '/todos/$id';
  static String todoEditPath(int id) => '/todos/$id/edit';
  static String collectionDetailPath(int id) => '/collection/$id';
  static String dailyReviewDetailPath(String date) => '/review/daily/$date';
  static String weeklyReportDetailPath(int weekNumber, {int? year}) {
    final query = year != null ? '?year=$year' : '';
    return '/review/weekly/$weekNumber$query';
  }
}
