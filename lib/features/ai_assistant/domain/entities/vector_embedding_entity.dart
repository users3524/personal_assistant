import 'dart:typed_data';

import 'milestone_entity.dart';

class VectorEmbeddingEntity {
  final int? id;
  final MilestoneSourceType sourceType;
  final int? sourceId;
  final String embeddingModel;
  final int dimension;
  final Uint8List vectorData;
  final String storageBackend;
  final String encodingVersion;
  final String? contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VectorEmbeddingEntity({
    this.id,
    required this.sourceType,
    this.sourceId,
    required this.embeddingModel,
    required this.dimension,
    required this.vectorData,
    this.storageBackend = 'sqlite_blob',
    this.encodingVersion = 'float32_le_v1',
    this.contentHash,
    required this.createdAt,
    required this.updatedAt,
  });

  VectorEmbeddingEntity copyWith({
    int? id,
    MilestoneSourceType? sourceType,
    int? sourceId,
    String? embeddingModel,
    int? dimension,
    Uint8List? vectorData,
    String? storageBackend,
    String? encodingVersion,
    String? contentHash,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VectorEmbeddingEntity(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      dimension: dimension ?? this.dimension,
      vectorData: vectorData ?? this.vectorData,
      storageBackend: storageBackend ?? this.storageBackend,
      encodingVersion: encodingVersion ?? this.encodingVersion,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
