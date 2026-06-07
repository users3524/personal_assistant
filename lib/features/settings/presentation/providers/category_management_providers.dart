/// 文玩分类管理 Provider。
library;

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/collection_category.dart';

/// 默认初始分类
final List<CollectionCategory> _defaultCategories = [
  CollectionCategory(
    name: '核桃',
    subtypes: ['白狮子', '苹果园', '鸡心', '官帽', '虎头', '四座楼', '南将石', '磨盘', '蛤蟆头', '满天星'],
    metadataFields: ['边宽(mm)', '肚厚(mm)', '桩高(mm)', '重量(g)'],
    sortOrder: 0,
  ),
  CollectionCategory(
    name: '手串',
    subtypes: ['百香籽', '牛骨', '南红', '紫金鼠', '星月', '金刚', '凤眼', '猴头', '紫檀', '木患子'],
    metadataFields: ['尺寸(mm)', '串型', '重量(g)'],
    sortOrder: 1,
  ),
  CollectionCategory(
    name: '把件',
    subtypes: ['葫芦', '贝壳', '折扇', '竹雕', '核雕', '玉牌', '铜件', '牙角'],
    metadataFields: ['长宽高(mm)', '重量(g)'],
    sortOrder: 2,
  ),
];

/// 文玩分类管理 Provider
final collectionCategoriesProvider =
    StateNotifierProvider<CollectionCategoriesNotifier, List<CollectionCategory>>((ref) {
  return CollectionCategoriesNotifier();
});

class CollectionCategoriesNotifier extends StateNotifier<List<CollectionCategory>> {
  CollectionCategoriesNotifier() : super([..._defaultCategories]);

  void add(CollectionCategory cat) {
    if (state.any((c) => c.name == cat.name)) return;
    state = [...state, cat];
  }

  void update(String name, CollectionCategory updated) {
    state = state.map((c) => c.name == name ? updated : c).toList();
  }

  void remove(String name) {
    if (state.length <= 1) return;
    state = state.where((c) => c.name != name).toList();
  }

  /// 序列化为 JSON 字符串
  String toJson() => jsonEncode(state.map((c) => c.toJson()).toList());

  /// 从 JSON 字符串恢复
  void fromJson(String json) {
    try {
      final list = jsonDecode(json) as List;
      state = list.map((e) => CollectionCategory.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
  }

  /// 获取某分类的子类型列表
  List<String> subtypesOf(String category) =>
      state.where((c) => c.name == category).firstOrNull?.subtypes ?? [];

  /// 获取某分类的元数据字段列表
  List<String> metadataFieldsOf(String category) =>
      state.where((c) => c.name == category).firstOrNull?.metadataFields ?? [];
}
