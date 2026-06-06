/// 简历个人资料表定义（单例模式）。
library;

import 'package:drift/drift.dart';

class ResumeProfile extends Table {
  @override
  String get tableName => 'resume_profile';

  IntColumn get id => integer().autoIncrement()();    // 始终 id=1
  TextColumn get fullName => text()();
  TextColumn get avatarPath => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get personalSummary => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get jobTitle => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime())();
}
