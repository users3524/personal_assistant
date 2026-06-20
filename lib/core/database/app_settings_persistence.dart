/// 轻量级设置持久化 — 使用 JSON 文件存储不频繁变动的配置。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppSettingsPersistence {
  Map<String, dynamic>? _cache;
  bool _loaded = false;

  Future<Map<String, dynamic>> _load() async {
    if (_loaded && _cache != null) return _cache!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_settings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        _cache = jsonDecode(content) as Map<String, dynamic>;
      } else {
        _cache = {};
      }
    } catch (_) {
      _cache = {};
    }
    _loaded = true;
    return _cache!;
  }

  Future<void> _save() async {
    if (_cache == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_settings.json');
      await file.writeAsString(jsonEncode(_cache));
    } catch (_) {}
  }

  // ===== 每日翻牌推荐配置 =====
  Future<Map<String, int>> getDailyPickCounts() async {
    final data = await _load();
    final raw = data['dailyPickCounts'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  Future<void> setDailyPickCounts(Map<String, int> counts) async {
    final data = await _load();
    data['dailyPickCounts'] = counts;
    await _save();
  }

  // ===== 网格列数 =====
  Future<int> getGridColumns() async {
    final data = await _load();
    return (data['gridColumns'] as num?)?.toInt() ?? 2;
  }

  Future<void> setGridColumns(int count) async {
    final data = await _load();
    data['gridColumns'] = count;
    await _save();
  }

  // ===== 通知首次启动提示 =====
  Future<bool> isNotificationHintShown() async {
    final data = await _load();
    return (data['notificationHintShown'] as bool?) ?? false;
  }

  Future<void> setNotificationHintShown() async {
    final data = await _load();
    data['notificationHintShown'] = true;
    await _save();
  }

  // ===== 文玩分类持久化 =====
  Future<int> getCollectionCategoriesSchemaVersion() async {
    final data = await _load();
    return (data['collectionCategoriesSchemaVersion'] as num?)?.toInt() ?? 1;
  }

  Future<List<Map<String, dynamic>>> getCollectionCategories() async {
    final data = await _load();
    return (data['collectionCategories'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
  }

  Future<void> setCollectionCategories(
    List<Map<String, dynamic>> categories, {
    int? schemaVersion,
  }) async {
    final data = await _load();
    data['collectionCategories'] = categories;
    if (schemaVersion != null) {
      data['collectionCategoriesSchemaVersion'] = schemaVersion;
    }
    await _save();
  }
}
