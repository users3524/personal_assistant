/// 文玩分类管理 Provider。
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/collection_category.dart';
import '../../../../core/database/app_settings_persistence.dart';
import '../../../../core/database/app_database.dart'
    hide CollectionCategory, CollectionCategoriesCompanion;

/// 默认初始分类
const int _collectionCategoriesSchemaVersion = 2;

const CollectionCategory _longStringCategory = CollectionCategory(
  name: '长串',
  subtypes: ['星月', '金刚', '凤眼', '百香籽', '菩提根', '椰蒂', '紫檀'],
  metadataFields: ['颗数', '尺寸(mm)', '重量(g)'],
  sortOrder: 3,
);

final List<CollectionCategory> _defaultCategories = [
  const CollectionCategory(
    name: '核桃',
    subtypes: [
      '白狮子',
      '苹果园',
      '鸡心',
      '官帽',
      '虎头',
      '四座楼',
      '南将石',
      '磨盘',
      '蛤蟆头',
      '满天星',
    ],
    metadataFields: ['边宽(mm)', '肚厚(mm)', '桩高(mm)', '重量(g)'],
    sortOrder: 0,
  ),
  const CollectionCategory(
    name: '手串',
    subtypes: ['百香籽', '牛骨', '南红', '紫金鼠', '星月', '金刚', '凤眼', '猴头', '紫檀', '木患子'],
    metadataFields: ['尺寸(mm)', '串型', '重量(g)'],
    sortOrder: 1,
  ),
  const CollectionCategory(
    name: '把件',
    subtypes: ['葫芦', '贝壳', '折扇', '竹雕', '核雕', '玉牌', '铜件', '牙角'],
    metadataFields: ['长宽高(mm)', '重量(g)'],
    sortOrder: 2,
  ),
  _longStringCategory,
];

List<CollectionCategory> _initialDefaultCategories() => [..._defaultCategories];

List<CollectionCategory> _appendMissingCategories(
  List<CollectionCategory> categories,
  Iterable<CollectionCategory> defaults,
) {
  final merged = [...categories];
  final names = merged.map((c) => c.name).toSet();
  var nextSortOrder = merged.isEmpty
      ? 0
      : merged.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

  for (final cat in defaults) {
    if (names.contains(cat.name)) continue;
    merged.add(cat.copyWith(sortOrder: nextSortOrder++));
    names.add(cat.name);
  }
  return merged;
}

/// 文玩分类管理 Provider
final collectionCategoriesProvider =
    StateNotifierProvider<
      CollectionCategoriesNotifier,
      List<CollectionCategory>
    >((ref) {
      return CollectionCategoriesNotifier();
    });

class CollectionCategoriesNotifier
    extends StateNotifier<List<CollectionCategory>> {
  final AppSettingsPersistence _persistence = AppSettingsPersistence();

  CollectionCategoriesNotifier() : super(_initialDefaultCategories()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final raw = await _persistence.getCollectionCategories();
    if (raw.isNotEmpty) {
      final schemaVersion = await _persistence
          .getCollectionCategoriesSchemaVersion();
      final restored = raw.map((e) => CollectionCategory.fromJson(e)).toList();
      state = schemaVersion < _collectionCategoriesSchemaVersion
          ? _appendMissingCategories(restored, [_longStringCategory])
          : restored;
      await _persist();
    }
  }

  /// 从持久化重新加载（导入备份后调用）
  Future<void> reload() async {
    await _loadFromStorage();
  }

  Future<void> _persist() async {
    await _persistence.setCollectionCategories(
      state.map((c) => c.toJson()).toList(),
      schemaVersion: _collectionCategoriesSchemaVersion,
    );
  }

  void add(CollectionCategory cat) {
    if (state.any((c) => c.name == cat.name)) return;
    state = [...state, cat];
    _persist();
  }

  void update(String name, CollectionCategory updated) {
    state = state.map((c) => c.name == name ? updated : c).toList();
    _persist();
  }

  /// 拖拽重排序：从 oldIndex 移到 newIndex
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final updated = [...state];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = updated;
    _persist();
  }

  void remove(String name) {
    if (state.length <= 1) return;
    state = state.where((c) => c.name != name).toList();
    _persist();
  }

  /// 从数据库导入后同步内存状态 — 检查数据库中的分类，没有则新建
  Future<void> reloadFromDb(AppDatabase db) async {
    final dbRows = await db.select(db.collectionCategories).get();
    final existingNames = state.map((c) => c.name).toSet();
    for (final row in dbRows) {
      if (!existingNames.contains(row.name)) {
        final subtypes = (jsonDecode(row.subtypes) as List).cast<String>();
        final fields = (jsonDecode(row.metadataFields) as List).cast<String>();
        state = [
          ...state,
          CollectionCategory(
            name: row.name,
            subtypes: subtypes,
            metadataFields: fields,
            sortOrder: row.sortOrder,
          ),
        ];
      }
    }
    state = _appendMissingCategories(state, [_longStringCategory]);
    _persist();
  }

  /// 序列化为 JSON 字符串
  String toJson() => jsonEncode(state.map((c) => c.toJson()).toList());

  /// 从 JSON 字符串恢复
  void fromJson(String json) {
    try {
      final list = jsonDecode(json) as List;
      state = _appendMissingCategories(
        list
            .map((e) => CollectionCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        [_longStringCategory],
      );
    } catch (_) {}
  }

  /// 同步到 SQLite 数据库（导出前确保数据完整）
  Future<void> syncToDb(AppDatabase db) async {
    await db.delete(db.collectionCategories).go();
    state = _appendMissingCategories(state, [_longStringCategory]);
    for (final cat in state) {
      await db.customStatement(
        'INSERT INTO collection_categories (name, subtypes, metadata_fields, sort_order) VALUES (?, ?, ?, ?)',
        [
          cat.name,
          jsonEncode(cat.subtypes),
          jsonEncode(cat.metadataFields),
          cat.sortOrder,
        ],
      );
    }
  }

  /// 从 SQLite 数据库恢复（导入后同步到持久化）
  Future<void> restoreFromDb(AppDatabase db) async {
    final rows = await db.select(db.collectionCategories).get();
    if (rows.isEmpty) return;
    state = _appendMissingCategories(
      rows
          .map(
            (r) => CollectionCategory(
              name: r.name,
              subtypes: _parseJsonList(r.subtypes),
              metadataFields: _parseJsonList(r.metadataFields),
              sortOrder: r.sortOrder,
            ),
          )
          .toList(),
      [_longStringCategory],
    );
    _persist();
  }

  List<String> _parseJsonList(String json) {
    try {
      return (jsonDecode(json) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// 获取某分类的子类型列表
  List<String> subtypesOf(String category) =>
      state.where((c) => c.name == category).firstOrNull?.subtypes ?? [];

  /// 获取某分类的元数据字段列表
  List<String> metadataFieldsOf(String category) =>
      state.where((c) => c.name == category).firstOrNull?.metadataFields ?? [];
}
