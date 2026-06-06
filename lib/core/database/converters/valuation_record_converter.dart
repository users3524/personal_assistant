/// 估值记录类型转换器。
///
/// 将 List<ValuationRecord> 序列化为 JSON 字符串存入 SQLite。
/// 用于 AntiqueItems 表中的 valuationHistory 字段（备选方案），
/// 推荐方案是使用独立的 ValuationRecords 关联表。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

class ValuationRecord {
  final DateTime date;
  final double amount;
  final String? remark;

  ValuationRecord({
    required this.date,
    required this.amount,
    this.remark,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'remark': remark,
      };

  factory ValuationRecord.fromJson(Map<String, dynamic> json) =>
      ValuationRecord(
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        remark: json['remark'] as String?,
      );
}

class ValuationRecordListConverter
    extends TypeConverter<List<ValuationRecord>, String> {
  const ValuationRecordListConverter();

  @override
  List<ValuationRecord> fromSql(String column) {
    final list = jsonDecode(column) as List;
    return list
        .map((e) => ValuationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  String toSql(List<ValuationRecord> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());
}
