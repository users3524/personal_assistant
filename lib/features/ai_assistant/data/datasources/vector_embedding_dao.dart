import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/milestone_entity.dart';
import '../../domain/entities/vector_embedding_entity.dart';
import '../../domain/services/vector_data_codec.dart';

class VectorEmbeddingDao {
  final AppDatabase _db;
  final VectorDataCodec _codec;

  VectorEmbeddingDao(
    this._db, {
    VectorDataCodec codec = const VectorDataCodec(),
  }) : _codec = codec;

  VectorEmbeddingEntity _toEntity(VectorEmbedding row) {
    return VectorEmbeddingEntity(
      id: row.id,
      sourceType: MilestoneSourceType.fromStorage(row.sourceType),
      sourceId: row.sourceId,
      embeddingModel: row.embeddingModel,
      dimension: row.dimension,
      vectorData: row.vectorData,
      storageBackend: row.storageBackend,
      encodingVersion: row.encodingVersion,
      contentHash: row.contentHash,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  VectorEmbeddingsCompanion _toCompanion(VectorEmbeddingEntity entity) {
    return VectorEmbeddingsCompanion(
      sourceType: Value(entity.sourceType.storageValue),
      sourceId: Value(entity.sourceId),
      embeddingModel: Value(entity.embeddingModel),
      dimension: Value(entity.dimension),
      vectorData: Value(entity.vectorData),
      storageBackend: Value(entity.storageBackend),
      encodingVersion: Value(entity.encodingVersion),
      contentHash: Value(entity.contentHash),
      createdAt: Value(entity.createdAt),
      updatedAt: Value(entity.updatedAt),
    );
  }

  Future<VectorEmbeddingEntity> upsert(VectorEmbeddingEntity entity) async {
    _validate(entity);
    final id = await _db
        .into(_db.vectorEmbeddings)
        .insert(_toCompanion(entity), mode: InsertMode.insertOrReplace);
    return entity.copyWith(id: id);
  }

  Future<VectorEmbeddingEntity?> getBySource({
    required MilestoneSourceType sourceType,
    int? sourceId,
    required String embeddingModel,
    required int dimension,
  }) async {
    _validateSource(sourceType: sourceType, sourceId: sourceId);
    final row =
        await (_db.select(_db.vectorEmbeddings)..where(
              (t) =>
                  t.sourceType.equals(sourceType.storageValue) &
                  (sourceId == null
                      ? t.sourceId.isNull()
                      : t.sourceId.equals(sourceId)) &
                  t.embeddingModel.equals(embeddingModel) &
                  t.dimension.equals(dimension),
            ))
            .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  Future<List<VectorEmbeddingEntity>> getByModel({
    required String embeddingModel,
    required int dimension,
  }) async {
    final rows =
        await (_db.select(_db.vectorEmbeddings)
              ..where(
                (t) =>
                    t.embeddingModel.equals(embeddingModel) &
                    t.dimension.equals(dimension),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    return rows.map(_toEntity).toList();
  }

  Future<int> deleteBySource({
    required MilestoneSourceType sourceType,
    int? sourceId,
  }) async {
    _validateSource(sourceType: sourceType, sourceId: sourceId);
    return (_db.delete(_db.vectorEmbeddings)..where(
          (t) =>
              t.sourceType.equals(sourceType.storageValue) &
              (sourceId == null
                  ? t.sourceId.isNull()
                  : t.sourceId.equals(sourceId)),
        ))
        .go();
  }

  void _validate(VectorEmbeddingEntity entity) {
    _validateSource(sourceType: entity.sourceType, sourceId: entity.sourceId);
    if (entity.embeddingModel.trim().isEmpty) {
      throw ArgumentError.value(
        entity.embeddingModel,
        'embeddingModel',
        'Embedding model must not be empty.',
      );
    }
    if (entity.dimension <= 0) {
      throw ArgumentError.value(
        entity.dimension,
        'dimension',
        'Embedding dimension must be positive.',
      );
    }
    if (entity.vectorData.isEmpty) {
      throw ArgumentError.value(
        entity.vectorData.length,
        'vectorData',
        'Vector data must not be empty.',
      );
    }
    _codec.validateBytes(entity.vectorData, dimension: entity.dimension);
    if (entity.storageBackend != 'sqlite_blob') {
      throw ArgumentError.value(
        entity.storageBackend,
        'storageBackend',
        'Only sqlite_blob vector storage is supported.',
      );
    }
    if (entity.encodingVersion != VectorDataCodec.encodingVersion) {
      throw ArgumentError.value(
        entity.encodingVersion,
        'encodingVersion',
        'Only ${VectorDataCodec.encodingVersion} vector encoding is supported.',
      );
    }
  }

  void _validateSource({
    required MilestoneSourceType sourceType,
    int? sourceId,
  }) {
    if (sourceType == MilestoneSourceType.manual) {
      if (sourceId != null) {
        throw ArgumentError.value(
          sourceId,
          'sourceId',
          'Manual vector sources must not have a source id.',
        );
      }
      return;
    }
    if (sourceId == null) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Non-manual vector sources require a source id.',
      );
    }
  }
}
