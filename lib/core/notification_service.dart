/// 本地通知服务 — 使用 flutter_local_notifications 实现每日/每周定时提醒。
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _dailyReviewId = 1001;
  static const _weeklyReportId = 1002;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // 初始化时区数据
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  /// 请求通知权限（Android 13+ 需要运行时权限）
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; // iOS 在 init 时已请求
  }

  /// 调度每日复盘提醒
  Future<void> scheduleDailyReview(int hour, int minute) async {
    await cancelDailyReview();

    // 使用 tz 时区
    final now = tz.TZDateTime.now(tz.local);
    var nextDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now)) {
      nextDate = nextDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyReviewId,
      '每日复盘提醒',
      '今天还没有复盘哦，花一分钟记录一下吧 📝',
      nextDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_review',
          '每日复盘',
          channelDescription: '每日复盘提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 取消每日复盘提醒
  Future<void> cancelDailyReview() async {
    await _plugin.cancel(_dailyReviewId);
  }

  /// 调度每周周报提醒（每周日指定时间）
  Future<void> scheduleWeeklyReport(int hour, int minute) async {
    await cancelWeeklyReport();

    final now = tz.TZDateTime.now(tz.local);
    // 找到下一个周日
    var nextSunday = now.add(Duration(days: (DateTime.sunday - now.weekday + 7) % 7));
    nextSunday = tz.TZDateTime(tz.local, nextSunday.year, nextSunday.month, nextSunday.day, hour, minute);
    if (nextSunday.isBefore(now) || nextSunday.isAtSameMomentAs(now)) {
      nextSunday = nextSunday.add(const Duration(days: 7));
    }

    await _plugin.zonedSchedule(
      _weeklyReportId,
      '每周周报提醒',
      '又到周日啦，花几分钟做一下本周复盘吧 📊',
      nextSunday,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_report',
          '每周周报',
          channelDescription: '每周周报提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// 取消每周周报提醒
  Future<void> cancelWeeklyReport() async {
    await _plugin.cancel(_weeklyReportId);
  }

  /// 根据设置更新提醒
  Future<void> updateFromSettings({
    required bool dailyEnabled,
    required int dailyHour,
    required int dailyMinute,
    required bool weeklyEnabled,
    required int weeklyHour,
    required int weeklyMinute,
  }) async {
    if (dailyEnabled) {
      await scheduleDailyReview(dailyHour, dailyMinute);
    } else {
      await cancelDailyReview();
    }

    if (weeklyEnabled) {
      await scheduleWeeklyReport(weeklyHour, weeklyMinute);
    } else {
      await cancelWeeklyReport();
    }
  }

  /// 发送一条即时测试通知
  Future<void> sendTestNotification() async {
    await _plugin.show(
      9999,
      '测试通知',
      '如果看到这条通知，说明通知功能正常工作 ✅',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          '测试',
          channelDescription: '测试通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
