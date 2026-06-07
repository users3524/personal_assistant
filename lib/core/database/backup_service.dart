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

    final tableOrder = [
      'user_preferences', 'todos', 'antique_items', 'valuation_records',
      'patting_logs', 'daily_reviews', 'weekly_reports',
      'resume_profile', 'work_experiences', 'educations',
      'skill_items', 'project_experiences',
    ];

    // 每张表的 snake_case 列名，与实际 SQL schema 一致
    const tableColumns = {
      'user_preferences': ['id','theme_mode','language','notification_enabled','ai_provider','ai_api_key','ai_base_url','ai_model','daily_review_time','weekly_report_day','resume_template_id','created_at','updated_at'],
      'todos': ['id','title','description','category','priority','due_date','status','tags','is_starred','started_at','completed_at','cancelled_at','actual_minutes','delay_count','created_at','updated_at'],
      'antique_items': ['id','name','category','subtype','description','acquired_date','acquired_price','source_seller','condition','current_valuation','image_paths','category_metadata','fingerprints','notes','created_at','updated_at'],
      'valuation_records': ['id','item_id','date','amount','remark','created_at'],
      'patting_logs': ['id','item_id','date','duration_minutes','method','note','photo_paths','created_at'],
      'daily_reviews': ['id','date','summary','highlights','improvements','energy_level','mood_level','completed_todo_ids','patting_minutes','ai_comment','ai_suggestion','is_ai_generated','is_manually_edited','created_at','updated_at'],
      'weekly_reports': ['id','week_number','year','overview','highlights','improvements','next_week_plan','is_ai_generated','is_manually_edited','created_at','updated_at'],
      'resume_profile': ['id','name','email','phone','website','summary','location','created_at','updated_at'],
      'work_experiences': ['id','company','position','start_date','end_date','description','is_visible','sort_order','created_at','updated_at'],
      'educations': ['id','school','major','degree','start_date','end_date','description','is_visible','sort_order','created_at','updated_at'],
      'skill_items': ['id','name','category','proficiency','is_visible','sort_order','created_at','updated_at'],
      'project_experiences': ['id','name','url','start_date','end_date','description','is_visible','sort_order','image_paths','created_at','updated_at'],
    };

    // camelCase → snake_case（drift.toJson 输出的是 camelCase）
    String _snake(String c) {
      // 确保首字母 D/N 不会被 _ 包围：acquiredDate→acquired_date
      final sb = StringBuffer();
      for (int i = 0; i < c.length; i++) {
        final ch = c[i];
        if (ch == ch.toUpperCase() && i > 0) {
          sb.write('_');
          sb.write(ch.toLowerCase());
        } else {
          sb.write(ch.toLowerCase());
        }
      }
      return sb.toString();
    }

    for (final tableName in tableOrder) {
      final rows = data[tableName];
      if (rows is! List || rows.isEmpty) continue;

      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;

        // 把 JSON 行转成 snake_case
        final snakeRow = <String, dynamic>{};
        for (final e in row.entries) {
          snakeRow[_snake(e.key)] = e.value;
        }

        final cols = tableColumns[tableName]!;
        final vals = <dynamic>[];

        for (final col in cols) {
          var v = snakeRow[col];

          // 图片列表：base64 → 解码写盘
          if ((col == 'image_paths' || col == 'photo_paths') && v is List) {
            v = v.map<dynamic>((p) {
              if (p is String && p.startsWith('base64:')) {
                return _decodeAndSaveImage(p.substring(7));
              }
              if (p is String && (p.startsWith('/data/') || p.startsWith('/storage/'))) {
                return null; // 别的设备的绝对路径，没用
              }
              return p;
            }).whereType<String>().toList();
          }

          vals.add(_toRaw(v));
        }

        final qs = vals.map((_) => '?').join(', ');
        final sql = 'INSERT OR REPLACE INTO $tableName (${cols.join(', ')}) VALUES ($qs)';
        try {
          await _db.customStatement(sql, vals);
        } catch (_) {}
      }
    }
  }

  dynamic _toRaw(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is List) return jsonEncode(v);
    return v.toString();
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
