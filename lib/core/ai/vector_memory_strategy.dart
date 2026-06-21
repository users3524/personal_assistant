/// Local vector memory storage and rebuild strategy.
library;

enum VectorStorageBackend {
  sqliteBlob;

  static VectorStorageBackend fromStorage(String? value) {
    return switch (value) {
      'sqlite_blob' => VectorStorageBackend.sqliteBlob,
      _ => VectorStorageBackend.sqliteBlob,
    };
  }

  String get storageValue {
    return switch (this) {
      VectorStorageBackend.sqliteBlob => 'sqlite_blob',
    };
  }
}

enum VectorRetrievalMode {
  dartLinearCosine;

  static VectorRetrievalMode fromStorage(String? value) {
    return switch (value) {
      'dart_linear_cosine' => VectorRetrievalMode.dartLinearCosine,
      _ => VectorRetrievalMode.dartLinearCosine,
    };
  }

  String get storageValue {
    return switch (this) {
      VectorRetrievalMode.dartLinearCosine => 'dart_linear_cosine',
    };
  }
}

enum VectorMemoryIndexStatus {
  disabled,
  missingIndex,
  storageMismatch,
  providerMismatch,
  modelMismatch,
  dimensionMismatch,
  ready,
}

class EmbeddingProfile {
  final String provider;
  final String model;
  final int dimension;

  const EmbeddingProfile({
    this.provider = '',
    this.model = '',
    this.dimension = 0,
  });

  factory EmbeddingProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EmbeddingProfile();
    return EmbeddingProfile(
      provider: json['provider']?.toString().trim() ?? '',
      model: json['model']?.toString().trim() ?? '',
      dimension: _readPositiveInt(json['dimension'], fallback: 0),
    );
  }

  bool get isConfigured => model.trim().isNotEmpty && dimension > 0;

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'model': model,
    'dimension': dimension,
  };
}

class VectorIndexMetadata {
  final VectorStorageBackend storageBackend;
  final EmbeddingProfile embeddingProfile;

  const VectorIndexMetadata({
    this.storageBackend = VectorStorageBackend.sqliteBlob,
    this.embeddingProfile = const EmbeddingProfile(),
  });
}

class VectorMemoryIndexDecision {
  final VectorMemoryIndexStatus status;
  final bool canSearch;
  final bool shouldRebuild;
  final String reason;

  const VectorMemoryIndexDecision({
    required this.status,
    required this.canSearch,
    required this.shouldRebuild,
    required this.reason,
  });
}

class VectorMemoryStrategy {
  static const defaultLinearScanThreshold = 10000;
  static const defaultRebuildBatchSize = 128;

  final bool enabled;
  final VectorStorageBackend storageBackend;
  final VectorRetrievalMode retrievalMode;
  final EmbeddingProfile embeddingProfile;
  final int linearScanThreshold;
  final int rebuildBatchSize;

  const VectorMemoryStrategy({
    this.enabled = false,
    this.storageBackend = VectorStorageBackend.sqliteBlob,
    this.retrievalMode = VectorRetrievalMode.dartLinearCosine,
    this.embeddingProfile = const EmbeddingProfile(),
    this.linearScanThreshold = defaultLinearScanThreshold,
    this.rebuildBatchSize = defaultRebuildBatchSize,
  });

  factory VectorMemoryStrategy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VectorMemoryStrategy();
    return VectorMemoryStrategy(
      enabled: json['enabled'] == true,
      storageBackend: VectorStorageBackend.fromStorage(
        json['storageBackend']?.toString(),
      ),
      retrievalMode: VectorRetrievalMode.fromStorage(
        json['retrievalMode']?.toString(),
      ),
      embeddingProfile: EmbeddingProfile.fromJson(
        json['embeddingProfile'] is Map<String, dynamic>
            ? json['embeddingProfile'] as Map<String, dynamic>
            : null,
      ),
      linearScanThreshold: _readPositiveInt(
        json['linearScanThreshold'],
        fallback: defaultLinearScanThreshold,
      ),
      rebuildBatchSize: _readPositiveInt(
        json['rebuildBatchSize'],
        fallback: defaultRebuildBatchSize,
      ),
    );
  }

  bool get isSearchConfigured => enabled && embeddingProfile.isConfigured;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'storageBackend': storageBackend.storageValue,
    'retrievalMode': retrievalMode.storageValue,
    'embeddingProfile': embeddingProfile.toJson(),
    'linearScanThreshold': linearScanThreshold,
    'rebuildBatchSize': rebuildBatchSize,
  };

  VectorMemoryIndexDecision evaluateIndex(VectorIndexMetadata? currentIndex) {
    if (!isSearchConfigured) {
      return const VectorMemoryIndexDecision(
        status: VectorMemoryIndexStatus.disabled,
        canSearch: false,
        shouldRebuild: false,
        reason: '向量记忆未启用或 embedding 元数据未配置完整。',
      );
    }

    if (currentIndex == null || !currentIndex.embeddingProfile.isConfigured) {
      return const VectorMemoryIndexDecision(
        status: VectorMemoryIndexStatus.missingIndex,
        canSearch: false,
        shouldRebuild: true,
        reason: '本地向量索引尚未建立，需要按当前 embedding 配置重建。',
      );
    }

    if (currentIndex.storageBackend != storageBackend) {
      return const VectorMemoryIndexDecision(
        status: VectorMemoryIndexStatus.storageMismatch,
        canSearch: false,
        shouldRebuild: true,
        reason: '本地向量存储后端不一致，需要重建索引。',
      );
    }

    final currentProfile = currentIndex.embeddingProfile;
    if (currentProfile.provider.isNotEmpty &&
        currentProfile.provider != embeddingProfile.provider) {
      return const VectorMemoryIndexDecision(
        status: VectorMemoryIndexStatus.providerMismatch,
        canSearch: false,
        shouldRebuild: true,
        reason: 'embedding 供应商不一致，需要重建索引。',
      );
    }
    if (currentProfile.model != embeddingProfile.model) {
      return const VectorMemoryIndexDecision(
        status: VectorMemoryIndexStatus.modelMismatch,
        canSearch: false,
        shouldRebuild: true,
        reason: 'embedding 模型不一致，需要重建索引。',
      );
    }
    if (currentProfile.dimension != embeddingProfile.dimension) {
      return const VectorMemoryIndexDecision(
        status: VectorMemoryIndexStatus.dimensionMismatch,
        canSearch: false,
        shouldRebuild: true,
        reason: 'embedding 维度不一致，需要重建索引。',
      );
    }

    return const VectorMemoryIndexDecision(
      status: VectorMemoryIndexStatus.ready,
      canSearch: true,
      shouldRebuild: false,
      reason: '',
    );
  }
}

int _readPositiveInt(dynamic value, {required int fallback}) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed <= 0) return fallback;
  return parsed;
}
