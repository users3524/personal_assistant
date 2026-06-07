/// 藏品领域实体。
library;

enum AntiqueCondition { perfect, good, fair, poor }

class AntiqueEntity {
  final int? id;
  final String name;
  final String category;
  final String? subtype;
  final String? description;
  final DateTime acquiredDate;
  final double? acquiredPrice;
  final String? sourceSeller;
  final AntiqueCondition condition;
  final double? currentValuation;
  final List<String> imagePaths;
  final Map<String, String>? categoryMetadata; // 分类专属字段 (边宽/重量/尺寸等)
  final String? fingerprints;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AntiqueEntity({
    this.id,
    required this.name,
    required this.category,
    this.subtype,
    this.description,
    required this.acquiredDate,
    this.acquiredPrice,
    this.sourceSeller,
    this.condition = AntiqueCondition.good,
    this.currentValuation,
    this.imagePaths = const [],
    this.categoryMetadata,
    this.fingerprints,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  AntiqueEntity copyWith({
    int? id,
    String? name,
    String? category,
    String? subtype,
    String? description,
    DateTime? acquiredDate,
    double? acquiredPrice,
    String? sourceSeller,
    AntiqueCondition? condition,
    double? currentValuation,
    List<String>? imagePaths,
    Map<String, String>? categoryMetadata,
    String? fingerprints,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AntiqueEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      subtype: subtype ?? this.subtype,
      description: description ?? this.description,
      acquiredDate: acquiredDate ?? this.acquiredDate,
      acquiredPrice: acquiredPrice ?? this.acquiredPrice,
      sourceSeller: sourceSeller ?? this.sourceSeller,
      condition: condition ?? this.condition,
      currentValuation: currentValuation ?? this.currentValuation,
      imagePaths: imagePaths ?? this.imagePaths,
      categoryMetadata: categoryMetadata ?? this.categoryMetadata,
      fingerprints: fingerprints ?? this.fingerprints,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get conditionLabel {
    switch (condition) {
      case AntiqueCondition.perfect:
        return '全品';
      case AntiqueCondition.good:
        return '良好';
      case AntiqueCondition.fair:
        return '一般';
      case AntiqueCondition.poor:
        return '有损';
    }
  }
}

/// 估值记录领域实体。
class ValuationRecordEntity {
  final int? id;
  final int itemId;
  final DateTime date;
  final double amount;
  final String? remark;

  const ValuationRecordEntity({
    this.id,
    required this.itemId,
    required this.date,
    required this.amount,
    this.remark,
  });
}

/// 盘玩日志领域实体。
class PattingLogEntity {
  final int? id;
  final int itemId;
  final DateTime date;
  final int durationMinutes;
  final String method; // bare_hand | glove
  final String? note;
  final List<String> photoPaths;

  const PattingLogEntity({
    this.id,
    required this.itemId,
    required this.date,
    required this.durationMinutes,
    this.method = 'bare_hand',
    this.note,
    this.photoPaths = const [],
  });

  String get methodLabel =>
      method == 'bare_hand' ? '净手盘' : '手套盘';
}
