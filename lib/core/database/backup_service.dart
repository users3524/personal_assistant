/// 数据备份与恢复服务 — 纯 JSON 导出/导入。
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import '../security/api_key_store.dart';
import '../utils/image_utils.dart';

class BackupService {
  final AppDatabase _db;
  final ApiKeyStore _apiKeyStore;

  BackupService(this._db, {ApiKeyStore? apiKeyStore})
    : _apiKeyStore = apiKeyStore ?? SecureApiKeyStore();

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
    Future<List<String>?> encodePaths(List<String>? paths) async {
      if (paths == null || paths.isEmpty) return paths;
      final encoded = <String>[];
      for (final p in paths) {
        try {
          final file = await resolveImageFile(p);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            encoded.add('base64:${base64Encode(bytes)}');
            continue;
          }
        } catch (_) {}
        encoded.add(p); // 兜底保留原始路径
      }
      return encoded;
    }

    data['user_preferences'] = (await _db.select(_db.userPreferences).get())
        .map((r) => _sanitizeUserPreferences(_rowToMap(r)))
        .toList();
    data['todo_lists'] = (await _db.select(_db.todoLists).get())
        .map((r) => _rowToMap(r))
        .toList();
    data['todos'] = (await _db.select(_db.todos).get())
        .map((r) => _rowToMap(r))
        .toList();
    final antiqueItems = <Map<String, dynamic>>[];
    for (final row in await _db.select(_db.antiqueItems).get()) {
      final m = _rowToMap(row);
      m['currentValuation'] = null;
      if (m['imagePaths'] is List) {
        m['imagePaths'] = await encodePaths(
          (m['imagePaths'] as List).cast<String>(),
        );
      }
      antiqueItems.add(m);
    }
    data['antique_items'] = antiqueItems;
    data['valuation_records'] = const <Map<String, dynamic>>[];
    final pattingLogs = <Map<String, dynamic>>[];
    for (final row in await _db.select(_db.pattingLogs).get()) {
      final m = _rowToMap(row);
      if (m['photoPaths'] is List) {
        m['photoPaths'] = await encodePaths(
          (m['photoPaths'] as List).cast<String>(),
        );
      }
      pattingLogs.add(m);
    }
    data['patting_logs'] = pattingLogs;
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
    data['collection_categories'] =
        (await _db.select(_db.collectionCategories).get())
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
    await _db.delete(_db.todoLists).go();
    await _db.delete(_db.collectionCategories).go();
    await _db.delete(_db.userPreferences).go();
    await _apiKeyStore.delete();

    final tableOrder = [
      'user_preferences',
      'collection_categories',
      'todo_lists',
      'todos',
      'antique_items',
      'valuation_records',
      'patting_logs',
      'daily_reviews',
      'weekly_reports',
      'resume_profile',
      'work_experiences',
      'educations',
      'skill_items',
      'project_experiences',
    ];

    // 每张表的 snake_case 列名，与实际 SQL schema 一致
    const tableColumns = {
      'user_preferences': [
        'id',
        'theme_mode',
        'language',
        'notification_enabled',
        'ai_provider',
        'ai_api_key',
        'ai_base_url',
        'ai_model',
        'daily_review_time',
        'weekly_report_day',
        'resume_template_id',
        'todo_categories',
        'created_at',
        'updated_at',
      ],
      'collection_categories': [
        'id',
        'name',
        'subtypes',
        'metadata_fields',
        'sort_order',
        'created_at',
        'updated_at',
      ],
      'todo_lists': ['id', 'name', 'category', 'created_at'],
      'todos': [
        'id',
        'title',
        'list_id',
        'parent_id',
        'recurrence_rule',
        'description',
        'category',
        'priority',
        'due_date',
        'status',
        'tags',
        'is_starred',
        'started_at',
        'completed_at',
        'cancelled_at',
        'deleted_at',
        'actual_minutes',
        'delay_count',
        'created_at',
        'updated_at',
      ],
      'antique_items': [
        'id',
        'name',
        'category',
        'subtype',
        'description',
        'acquired_date',
        'acquired_price',
        'source_seller',
        'condition',
        'current_valuation',
        'image_paths',
        'category_metadata',
        'fingerprints',
        'notes',
        'created_at',
        'updated_at',
      ],
      'valuation_records': [
        'id',
        'item_id',
        'date',
        'amount',
        'remark',
        'created_at',
      ],
      'patting_logs': [
        'id',
        'item_id',
        'date',
        'duration_minutes',
        'method',
        'note',
        'photo_paths',
        'created_at',
      ],
      'daily_reviews': [
        'id',
        'date',
        'summary',
        'highlights',
        'improvements',
        'energy_level',
        'mood_level',
        'completed_todo_ids',
        'patting_minutes',
        'ai_comment',
        'ai_suggestion',
        'is_ai_generated',
        'is_manually_edited',
        'created_at',
        'updated_at',
      ],
      'weekly_reports': [
        'id',
        'week_number',
        'year',
        'overview',
        'highlights',
        'improvements',
        'next_week_plan',
        'is_ai_generated',
        'is_manually_edited',
        'created_at',
        'updated_at',
      ],
      'resume_profile': [
        'id',
        'full_name',
        'avatar_path',
        'email',
        'phone',
        'personal_summary',
        'website',
        'location',
        'job_title',
        'updated_at',
      ],
      'work_experiences': [
        'id',
        'company',
        'position',
        'start_date',
        'end_date',
        'description',
        'responsibilities',
        'tech_stack',
        'is_visible',
        'sort_order',
        'created_at',
        'updated_at',
      ],
      'educations': [
        'id',
        'school',
        'major',
        'degree',
        'start_date',
        'end_date',
        'description',
        'is_visible',
        'sort_order',
      ],
      'skill_items': [
        'id',
        'name',
        'category',
        'proficiency',
        'is_visible',
        'sort_order',
      ],
      'project_experiences': [
        'id',
        'name',
        'role',
        'description',
        'tech_stack',
        'key_deliverables',
        'badges',
        'link',
        'start_date',
        'end_date',
        'is_visible',
        'sort_order',
      ],
    };

    // camelCase → snake_case（drift.toJson 输出的是 camelCase）
    String snakeKey(String c) {
      // 确保首字母 D/N 不会被 _ 包围：acquiredDate→acquired_date
      if (c.contains('_')) {
        return c.toLowerCase();
      }
      final sb = StringBuffer();
      for (int i = 0; i < c.length; i++) {
        final ch = c[i];
        final code = ch.codeUnitAt(0);
        final isUpperAscii = code >= 65 && code <= 90;
        if (isUpperAscii && i > 0) {
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

      for (final row in _orderedRowsForRestore(tableName, rows)) {
        if (row is! Map<String, dynamic>) continue;

        // 把 JSON 行转成 snake_case
        final snakeRow = <String, dynamic>{};
        for (final e in row.entries) {
          snakeRow[snakeKey(e.key)] = e.value;
        }
        if (tableName == 'valuation_records') {
          continue;
        }
        final legacyAiApiKey = tableName == 'user_preferences'
            ? snakeRow['ai_api_key']?.toString()
            : null;
        if (tableName == 'user_preferences') {
          snakeRow['ai_api_key'] = null;
        }
        if (tableName == 'antique_items') {
          _archiveCurrentValuationIntoNotes(snakeRow);
        }

        final cols = tableColumns[tableName]!;
        final vals = <dynamic>[];

        for (final col in cols) {
          var v = snakeRow[col];
          v ??= _defaultRestoreValue(tableName, col);

          // 图片列表：base64 → 解码写盘
          if ((col == 'image_paths' || col == 'photo_paths') && v is List) {
            v = v
                .map<dynamic>((p) {
                  if (p is String && p.startsWith('base64:')) {
                    return _decodeAndSaveImage(p.substring(7));
                  }
                  if (p is String &&
                      (p.startsWith('/data/') || p.startsWith('/storage/'))) {
                    return null; // 别的设备的绝对路径，没用
                  }
                  return p;
                })
                .whereType<String>()
                .toList();
          }

          vals.add(_toRaw(v, col));
        }

        final qs = vals.map((_) => '?').join(', ');
        final sql =
            'INSERT OR REPLACE INTO $tableName (${cols.join(', ')}) VALUES ($qs)';
        await _db.customStatement(sql, vals);

        if (tableName == 'user_preferences' &&
            legacyAiApiKey != null &&
            legacyAiApiKey.trim().isNotEmpty) {
          await _apiKeyStore.write(legacyAiApiKey);
        }
      }

      if (tableName == 'valuation_records') {
        await _archiveLegacyValuationRecords(rows);
      }
    }

    // 导入后处理：从备份中提取新建的分类数据并通知上层
    final rawCats = data['collection_categories'];
    if (rawCats is List && rawCats.isNotEmpty) {
      // 分类已通过 customStatement 写入数据库
    }
  }

  /// 日期列后缀集合 — 备份 JSON 中日期以 ms epoch 存储（drift toJson 序列化输出），
  /// 但 drift 在 SQLite 中以 **秒** 存储。customStatement 绕过 drift 类型系统，
  /// 需手动将 ms 转为秒，否则读回时被 ×1000 导致日期膨胀（如 58400 年）。
  static const _dateColumnSuffixes = {'_at', '_date'};
  static const _exactDateColumns = {'date'};

  /// 是否为日期列
  bool _isDateColumn(String col) {
    return _exactDateColumns.contains(col) ||
        _dateColumnSuffixes.any((s) => col.endsWith(s));
  }

  /// 将 ms epoch 转换为 drift SQLite 存储用的秒 epoch
  int _msToSeconds(int ms) => (ms / 1000).round();

  dynamic _toRaw(dynamic v, [String? columnName]) {
    if (v == null) return null;
    if (v is int) {
      // 日期列：JSON 中是 ms epoch，SQLite 用秒 epoch → 除以 1000
      if (columnName != null && _isDateColumn(columnName)) {
        return _msToSeconds(v);
      }
      return v;
    }
    if (v is double) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is List) return jsonEncode(v);
    // ISO 8601 日期字符串 → DateTime → 转换成秒 epoch 给 SQLite
    if (v is String && v.length >= 19 && v[4] == '-' && v[10] == 'T') {
      final dt = DateTime.tryParse(v);
      if (dt != null) return _msToSeconds(dt.millisecondsSinceEpoch);
    }
    return v.toString();
  }

  Map<String, dynamic> _rowToMap(DataClass row) {
    return row.toJson();
  }

  Map<String, dynamic> _sanitizeUserPreferences(Map<String, dynamic> row) {
    final sanitized = Map<String, dynamic>.from(row);
    sanitized['aiApiKey'] = null;
    return sanitized;
  }

  void _archiveCurrentValuationIntoNotes(Map<String, dynamic> snakeRow) {
    final valuation = snakeRow['current_valuation'];
    if (valuation is num && valuation > 0) {
      final existingNotes = snakeRow['notes']?.toString();
      final archive =
          '\n\n【历史估值归档】\n'
          '- 当前估值: ${_formatMoney(valuation)} 元';
      snakeRow['notes'] = _appendArchiveText(existingNotes, archive);
    }
    snakeRow['current_valuation'] = null;
  }

  Future<void> _archiveLegacyValuationRecords(List<dynamic> rows) async {
    final grouped = <int, List<Map<dynamic, dynamic>>>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final itemId = _readInt(row, 'item_id', 'itemId');
      if (itemId == null) continue;
      grouped.putIfAbsent(itemId, () => []).add(row);
    }

    for (final entry in grouped.entries) {
      final records = entry.value;
      records.sort((a, b) {
        final aDate = _readDateMillis(a, 'date');
        final bDate = _readDateMillis(b, 'date');
        return aDate.compareTo(bDate);
      });

      final buffer = StringBuffer('\n\n【历史估值归档】');
      for (final record in records) {
        final amount = _readNum(record, 'amount');
        if (amount == null) continue;
        final dateText = _formatBackupDate(_readValue(record, 'date'));
        final remark = _readValue(record, 'remark')?.toString().trim();
        buffer.write('\n- $dateText | 金额: ${_formatMoney(amount)} 元');
        if (remark != null && remark.isNotEmpty) {
          buffer.write(' | 备注: $remark');
        }
      }

      final archiveText = buffer.toString();
      if (archiveText == '\n\n【历史估值归档】') continue;
      await _db.customStatement(
        'UPDATE antique_items SET notes = COALESCE(notes, "") || ? WHERE id = ?',
        [archiveText, entry.key],
      );
    }
  }

  String _appendArchiveText(String? existing, String archive) {
    if (existing == null || existing.trim().isEmpty) {
      return archive.trimLeft();
    }
    return '$existing$archive';
  }

  dynamic _readValue(Map<dynamic, dynamic> row, String key) {
    return row[key] ?? row[_snakeToCamel(key)];
  }

  int? _readInt(Map<dynamic, dynamic> row, String snake, String camel) {
    final value = row[snake] ?? row[camel];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  num? _readNum(Map<dynamic, dynamic> row, String key) {
    final value = _readValue(row, key);
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  int _readDateMillis(Map<dynamic, dynamic> row, String key) {
    final value = _readValue(row, key);
    if (value is int) {
      return value > 100000000000 ? value : value * 1000;
    }
    if (value is num) {
      final intValue = value.toInt();
      return intValue > 100000000000 ? intValue : intValue * 1000;
    }
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.millisecondsSinceEpoch ?? 0;
  }

  String _formatBackupDate(dynamic value) {
    DateTime? date;
    if (value is int) {
      date = DateTime.fromMillisecondsSinceEpoch(
        value > 100000000000 ? value : value * 1000,
      );
    } else if (value is num) {
      final intValue = value.toInt();
      date = DateTime.fromMillisecondsSinceEpoch(
        intValue > 100000000000 ? intValue : intValue * 1000,
      );
    } else {
      date = DateTime.tryParse(value?.toString() ?? '');
    }
    if (date == null) return '日期未知';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatMoney(num amount) {
    if (amount % 1 == 0) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  String _snakeToCamel(String key) {
    final parts = key.split('_');
    if (parts.length <= 1) return key;
    return parts.first +
        parts
            .skip(1)
            .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
            .join();
  }

  dynamic _defaultRestoreValue(String tableName, String columnName) {
    const emptyListColumns = {
      'todo_categories',
      'tags',
      'image_paths',
      'photo_paths',
      'completed_todo_ids',
      'responsibilities',
      'tech_stack',
      'key_deliverables',
      'badges',
    };
    if (emptyListColumns.contains(columnName)) {
      return const <String>[];
    }

    if (tableName == 'todos' && columnName == 'delay_count') {
      return 0;
    }
    if (tableName == 'todos' && columnName == 'priority') {
      return 3;
    }
    if (tableName == 'todos' && columnName == 'category') {
      return 'life';
    }
    if (tableName == 'todos' && columnName == 'status') {
      return 'pending';
    }
    if (tableName == 'todos' && columnName == 'is_starred') {
      return false;
    }
    if (tableName == 'daily_reviews' && columnName == 'patting_minutes') {
      return 0;
    }
    if (tableName == 'daily_reviews' && columnName == 'is_ai_generated') {
      return false;
    }
    if (tableName == 'daily_reviews' && columnName == 'is_manually_edited') {
      return false;
    }
    if (tableName == 'weekly_reports' && columnName == 'is_ai_generated') {
      return false;
    }
    if (tableName == 'weekly_reports' && columnName == 'is_manually_edited') {
      return false;
    }
    if (columnName == 'is_visible') {
      return true;
    }
    if (columnName == 'sort_order') {
      return 0;
    }

    return null;
  }

  Iterable<dynamic> _orderedRowsForRestore(
    String tableName,
    List<dynamic> rows,
  ) {
    if (tableName != 'todos') {
      return rows;
    }

    final ordered = List<dynamic>.from(rows);
    final parentsById = <Object?, Object?>{};
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        parentsById[row['id']] = row['parentId'] ?? row['parent_id'];
      }
    }

    int depthOf(Object? id) {
      var depth = 0;
      var parentId = parentsById[id];
      final seen = <Object?>{};
      while (parentId != null && seen.add(parentId)) {
        depth++;
        parentId = parentsById[parentId];
      }
      return depth;
    }

    ordered.sort((a, b) {
      final aDepth = a is Map<String, dynamic> ? depthOf(a['id']) : 0;
      final bDepth = b is Map<String, dynamic> ? depthOf(b['id']) : 0;
      return aDepth.compareTo(bDepth);
    });
    return ordered;
  }

  /// 将 Base64 解码并写入文件，返回文件路径
  String _decodeAndSaveImage(String base64str) {
    try {
      final bytes = base64Decode(base64str);
      final dir = Directory(
        '${Directory.systemTemp.path}/personal_assistant_images',
      );
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
