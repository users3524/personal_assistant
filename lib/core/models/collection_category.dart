/// 文玩分类数据模型。
library;

/// 文玩分类（核桃/手串/把件等）
class CollectionCategory {
  final String name;
  final List<String> subtypes;
  final List<String> metadataFields;
  final int sortOrder;

  const CollectionCategory({
    required this.name,
    this.subtypes = const [],
    this.metadataFields = const [],
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'subtypes': subtypes,
    'metadataFields': metadataFields,
    'sortOrder': sortOrder,
  };

  factory CollectionCategory.fromJson(Map<String, dynamic> json) =>
      CollectionCategory(
        name: json['name'] as String,
        subtypes: (json['subtypes'] as List?)?.cast<String>() ?? [],
        metadataFields: (json['metadataFields'] as List?)?.cast<String>() ?? [],
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );

  CollectionCategory copyWith({
    String? name,
    List<String>? subtypes,
    List<String>? metadataFields,
    int? sortOrder,
  }) =>
      CollectionCategory(
        name: name ?? this.name,
        subtypes: subtypes ?? this.subtypes,
        metadataFields: metadataFields ?? this.metadataFields,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}
