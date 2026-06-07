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

  /// 收集所有数据（图片路径内容内联为 Base64）
  Future<Map<String, dynamic>> _collectData() async {
    final data = <String, dynamic>{};
    data['version'] = 1;
    data['exportedAt'] = DateTime.now().toIso8601String();

    // 辅助：将路径列表转为 Base64 列表
    List<String>? encodePaths(List<String>? paths) {
      if (paths == null || paths.isEmpty) return paths;
      return paths.map((p) {
        try {
          final file = File(p);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            return 'base64:${base64Encode(bytes)}';
          }
        } catch (_) {}
        return p; // 兜底保留原始路径
      }).toList();
    }

    data['user_preferences'] = (await _db.select(_db.userPreferences).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['todos'] = (await _db.select(_db.todos).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['antique_items'] = (await _db.select(_db.antiqueItems).get())
        .map((r) {
          final m = _rowToMap(r);
          if (m['imagePaths'] is List) m['imagePaths'] = encodePaths(m['imagePaths'] as List<String>?);
          return m;
        }).toList();
    data['valuation_records'] = (await _db.select(_db.valuationRecords).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['patting_logs'] = (await _db.select(_db.pattingLogs).get())
        .map((r) {
          final m = _rowToMap(r);
          if (m['photoPaths'] is List) m['photoPaths'] = encodePaths(m['photoPaths'] as List<String>?);
          return m;
        }).toList();
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

    // 逐表恢复 — 使用 Raw SQL INSERT，避免逐个构造 Companion
    final tableOrder = [
      'user_preferences', 'todos', 'antique_items', 'valuation_records',
      'patting_logs', 'daily_reviews', 'weekly_reports',
      'resume_profile', 'work_experiences', 'educations',
      'skill_items', 'project_experiences',
    ];

    // JSON key → SQL column name 映射 (drift toJson 使用 camelCase)
    String toSnakeCase(String camel) {
      return camel.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      );
    }

    String escapeValue(dynamic v) {
      if (v == null) return 'NULL';
      if (v is bool) return v ? '1' : '0';
      if (v is num) return v.toString();
      if (v is String) return "'${v.replaceAll("'", "''")}'";
      if (v is List) {
        final escaped = v.map((e) => "'${e.toString().replaceAll("'", "''")}'").join(',');
        return "'[$escaped]'";
      }
      return "'${v.toString().replaceAll("'", "''")}'";
    }

    for (final tableName in tableOrder) {
      final rows = data[tableName];
      if (rows is! List || rows.isEmpty) continue;

      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;

        final columns = <String>[];
        final values = <String>[];
        for (final entry in row.entries) {
          var val = entry.value;

          // 解码 Base64 内联图片 → 写入文件 → 替换为文件路径
          if ((entry.key == 'imagePaths' || entry.key == 'photoPaths') && val is List) {
            val = val.map((p) {
              if (p is String && p.startsWith('base64:')) {
                return _decodeAndSaveImage(p.substring(7));
              }
              return p;
            }).toList();
          }
          // 跳过不可用的文件路径（不同设备的路径直接去掉）
          if ((entry.key == 'imagePaths' || entry.key == 'photoPaths') && val is List) {
            val = val.where((p) => p is String && p.isNotEmpty).toList();
          }

          columns.add(toSnakeCase(entry.key));
          values.add(escapeValue(val));
        }

        if (columns.isEmpty) continue;
        final sql = 'INSERT INTO $tableName (${columns.join(', ')}) VALUES (${values.join(', ')})';
        try {
          await _db.customStatement(sql);
        } catch (_) {
          // 单行失败不影响其他行
        }
      }
    }
  }

  Map<String, dynamic> _rowToMap(DataClass row) {
    return row.toJson();
  }

  /// 将 Base64 解码并写入文件，返回文件路径
  String _decodeAndSaveImage(String base64str) {
    try {
      final bytes = base64Decode(base64str);
      final dir = Directory('${Directory.systemTemp.path}/personal_assistant_images');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final fileName = 'restored_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      file.writeAsBytesSync(bytes);
      return file.path;
    } catch (_) {
      return '';
    }
  }
}
