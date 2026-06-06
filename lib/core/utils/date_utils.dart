/// 日期工具类
library;
import 'package:intl/intl.dart';

class DateUtils {
  DateUtils._();

  /// 格式化日期：2024-01-15
  static String toDateString(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  /// 格式化日期时间：2024-01-15 14:30
  static String toDateTimeString(DateTime date) =>
      DateFormat('yyyy-MM-dd HH:mm').format(date);

  /// 格式化时间：14:30
  static String toTimeString(DateTime date) =>
      DateFormat('HH:mm').format(date);

  /// 友好显示：今天、昨天、日期
  static String toFriendlyString(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return '今天';
    if (target == today.subtract(const Duration(days: 1))) return '昨天';
    if (target == today.add(const Duration(days: 1))) return '明天';
    return toDateString(date);
  }

  /// 获取当前周数（ISO 8601）
  static int getWeekNumber(DateTime date) {
    return int.parse(DateFormat('w').format(date));
  }

  /// 获取本周一
  static DateTime getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  /// 获取本周末（周日）
  static DateTime getWeekEnd(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day + (7 - weekday));
  }

  /// 判断是否在同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 判断是否在同一周
  static bool isSameWeek(DateTime a, DateTime b) {
    return getWeekNumber(a) == getWeekNumber(b) && a.year == b.year;
  }
}
