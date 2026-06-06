/// 将 List<String> 序列化为 JSON 字符串存入 SQLite。
///
/// drift 的 SQLite 后端不支持原生数组类型，需要使用 TypeConverter
/// 将 Dart 的 List<String> 转换为 SQLite 的 TEXT。
///
/// 使用示例：
/// ```dart
/// TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();
/// ```
library;

import 'dart:convert';

import 'package:drift/drift.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String column) =>
      (jsonDecode(column) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
