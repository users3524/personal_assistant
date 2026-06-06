/// 用户偏好设置表。
///
/// 单例模式（始终 id=1），存储用户的全局设置。
/// API Key 在存入前需通过 SecureStorage 进行 AES 加密。
library;

import 'package:drift/drift.dart';

class UserPreferences extends Table {
  @override
  String get tableName => 'user_preferences';

  IntColumn get id => integer().autoIncrement()();

  /// 主题模式：light | dark | system
  TextColumn get themeMode =>
      text().withDefault(const Constant('system'))();

  /// 语言：zh | en
  TextColumn get language => text().withDefault(const Constant('zh'))();

  /// 是否启用通知
  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(true))();

  /// AI 供应商：openai | azure | local
  TextColumn get aiProvider =>
      text().withDefault(const Constant('openai'))();

  /// AI API Key（AES 加密后存储）
  TextColumn get aiApiKey => text().nullable()();

  /// API Base URL（支持国内代理/自建）
  TextColumn get aiBaseUrl => text().nullable()();

  /// AI 模型名称
  TextColumn get aiModel => text().nullable()();

  /// 日报提醒时间，格式 HH:mm
  TextColumn get dailyReviewTime =>
      text().withDefault(const Constant('21:00'))();

  /// 周报提醒日：monday | sunday
  TextColumn get weeklyReportDay =>
      text().withDefault(const Constant('sunday'))();

  /// 启用的简历模板 ID
  IntColumn get resumeTemplateId =>
      integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime())();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime())();
}
