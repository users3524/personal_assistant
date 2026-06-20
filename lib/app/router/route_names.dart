/// 路由名称常量。
///
/// 集中管理所有路由路径，避免硬编码字符串。
library;

class RouteNames {
  RouteNames._();

  // 主壳
  static const String mainShell = '/';

  // 待办模块
  static const String todoList = '/todos';
  static const String todoNew = '/todos/new';
  static const String todoDetail = '/todos/:id';
  static const String todoEdit = '/todos/:id/edit';

  // 文玩（盘串）模块
  static const String collectionList = '/collection';
  static const String collectionNew = '/collection/new';
  static const String collectionDetail = '/collection/:id';
  static const String collectionEdit = '/collection/:id/edit';

  // 复盘模块
  static const String reviewHome = '/review';
  static const String dailyReviewNew = '/review/daily/new';
  static const String dailyReviewDetail = '/review/daily/:date';
  static const String dailyReviewEdit = '/review/daily/edit/:date';
  static const String weeklyReportDetail = '/review/weekly/:id';

  // 简历模块
  static const String resumeHome = '/resume';
  static const String resumePreview = '/resume/preview';
  static const String resumeTemplates = '/resume/templates';

  // 设置
  static const String settings = '/settings';

  // === 路径构建辅助 ===

  static String todoDetailPath(int id) => '/todos/$id';
  static String todoEditPath(int id) => '/todos/$id/edit';
  static String collectionDetailPath(int id) => '/collection/$id';
  static String dailyReviewDetailPath(String date) => '/review/daily/$date';
  static String weeklyReportDetailPath(int weekNumber, {int? year}) {
    final query = year != null ? '?year=$year' : '';
    return '/review/weekly/$weekNumber$query';
  }
}
