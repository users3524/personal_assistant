import 'package:drift/drift.dart';

const String createVectorEmbeddingsSourceIndex =
    'CREATE INDEX IF NOT EXISTS idx_vector_embeddings_source '
    'ON vector_embeddings(source_type, source_id)';
const String createVectorEmbeddingsModelDimensionIndex =
    'CREATE INDEX IF NOT EXISTS idx_vector_embeddings_model_dimension '
    'ON vector_embeddings(embedding_model, dimension)';
const String createVectorEmbeddingsUniqueIndex =
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_vector_embeddings_unique '
    'ON vector_embeddings('
    'source_type, COALESCE(source_id, -1), embedding_model, dimension)';

const vectorEmbeddingIndexStatements = [
  createVectorEmbeddingsSourceIndex,
  createVectorEmbeddingsModelDimensionIndex,
  createVectorEmbeddingsUniqueIndex,
];

@TableIndex.sql(createVectorEmbeddingsSourceIndex)
@TableIndex.sql(createVectorEmbeddingsModelDimensionIndex)
@TableIndex.sql(createVectorEmbeddingsUniqueIndex)
class VectorEmbeddings extends Table {
  @override
  String get tableName => 'vector_embeddings';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceType => text()();
  IntColumn get sourceId => integer().nullable()();
  TextColumn get embeddingModel => text()();
  IntColumn get dimension => integer()();
  BlobColumn get vectorData => blob()();
  TextColumn get storageBackend =>
      text().withDefault(const Constant('sqlite_blob'))();
  TextColumn get encodingVersion =>
      text().withDefault(const Constant('float32_le_v1'))();
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => const [
    "CHECK (source_type IN ('todo', 'daily_review', 'patting_log', 'manual'))",
    "CHECK ((source_type = 'manual' AND source_id IS NULL) OR "
        "(source_type <> 'manual' AND source_id IS NOT NULL))",
    'CHECK (dimension > 0)',
    'CHECK (length(vector_data) > 0)',
    'CHECK (storage_backend = "sqlite_blob")',
    'CHECK (encoding_version IN ("float32_le_v1"))',
  ];
}
