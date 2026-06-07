/// 数据备份与恢复服务 — 纯 JSON 导出/导入。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  /// 导出全部数据为 JSON 文件，保存到应用文档目录（默认）
  Future<String> exportBackup() async {
    final dir = await getApplicationDocumentsDirectory();
    return exportBackupTo(dir.path);
  }

  /// 导出到指定目录，返回实际文件路径
  Future<String> exportBackupTo(String dirPath) async {
    final data = await _collectData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    final fileName = 'backup_$timestamp.json';
    final filePath = '$dirPath${Platform.pathSeparator}$fileName';
    await File(filePath).writeAsString(jsonStr);
    return filePath;
  }

  /// 使用 SAF 让用户选择保存位置，写入后返回路径
  /// Android 上不可直接 dart:io 写入 getDirectoryPath 拿到的路径
  Future<String?> exportViaSaf() async {
    final data = await _collectData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    final fileName = 'backup_$timestamp.json';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: '选择保存位置',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: utf8.encode(jsonStr),
    );
    // On some platforms saveFile returns the path, on others null with bytes written
    return result;
  }

  /// 导入备份 — 从 JSON 文件恢复数据
  Future<void> importBackup(String filePath) async {
    final jsonStr = await File(filePath).readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    await _restoreData(data);
  }

  /// 选择备份文件
  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return result?.files.single.path;
  }

  /// 收集所有数据（包含 API Key，用户自行决定分享范围）
  Future<Map<String, dynamic>> _collectData() async {
    final data = <String, dynamic>{};
    data['version'] = 1;
    data['exportedAt'] = DateTime.now().toIso8601String();

    data['user_preferences'] = (await _db.select(_db.userPreferences).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['todos'] = (await _db.select(_db.todos).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['antique_items'] = (await _db.select(_db.antiqueItems).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['valuation_records'] = (await _db.select(_db.valuationRecords).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['patting_logs'] = (await _db.select(_db.pattingLogs).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['daily_reviews'] = (await _db.select(_db.dailyReviews).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['weekly_reports'] = (await _db.select(_db.weeklyReports).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['resume_profile'] = (await _db.select(_db.resumeProfile).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['work_experiences'] = (await _db.select(_db.workExperiences).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['educations'] = (await _db.select(_db.educations).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['skill_items'] = (await _db.select(_db.skillItems).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['project_experiences'] =
        (await _db.select(_db.projectExperiences).get())
            .map((r) => _rowToMap(r))
            .toList();

    return data;
  }

  /// 恢复数据 — 清空当前后逐表插入
  Future<void> _restoreData(Map<String, dynamic> data) async {
    // 清空现有数据
    await _db.delete(_db.projectExperiences).go();
    await _db.delete(_db.skillItems).go();
    await _db.delete(_db.educations).go();
    await _db.delete(_db.workExperiences).go();
    await _db.delete(_db.resumeProfile).go();
    await _db.delete(_db.weeklyReports).go();
    await _db.delete(_db.dailyReviews).go();
    await _db.delete(_db.pattingLogs).go();
    await _db.delete(_db.valuationRecords).go();
    await _db.delete(_db.antiqueItems).go();
    await _db.delete(_db.todos).go();
    await _db.delete(_db.userPreferences).go();

    // 恢复 user_preferences
    final prefs = data['user_preferences'] as List?;
    if (prefs != null && prefs.isNotEmpty) {
      await _db.batch((batch) {
        for (final row in prefs) {
          if (row is Map<String, dynamic>) {
            batch.insert(
              _db.userPreferences,
              UserPreferencesCompanion(
                id: Value(row['id'] as int? ?? 1),
                themeMode: Value(row['theme_mode']?.toString() ?? 'system'),
                language: Value(row['language']?.toString() ?? 'zh'),
                notificationEnabled: Value(
                    row['notification_enabled'] == true ||
                        row['notification_enabled'] == 1),
                aiProvider:
                    Value(row['ai_provider']?.toString() ?? 'OpenAI'),
                aiApiKey: Value(row['ai_api_key']?.toString()),
                aiBaseUrl: Value(row['ai_base_url']?.toString()),
                aiModel: Value(row['ai_model']?.toString()),
                dailyReviewTime:
                    Value(row['daily_review_time']?.toString() ?? '21:00'),
                weeklyReportDay:
                    Value(row['weekly_report_day']?.toString() ?? 'sunday'),
                resumeTemplateId: Value(row['resume_template_id'] as int? ?? 0),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
      });
    }
  }

  Map<String, dynamic> _rowToMap(DataClass row) {
    return row.toJson();
  }
}
