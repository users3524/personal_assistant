enum ReviewGenerationJobStatus {
  pending,
  success,
  failed;

  static ReviewGenerationJobStatus fromStorage(String value) {
    return ReviewGenerationJobStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => ReviewGenerationJobStatus.pending,
    );
  }

  String get storageValue => name;
}

class ReviewGenerationJobEntity {
  final int? id;
  final String targetDate;
  final ReviewGenerationJobStatus status;
  final String? rawAssetsDump;
  final int attemptCount;
  final String? failureReason;
  final DateTime? processedAt;
  final DateTime createdAt;

  const ReviewGenerationJobEntity({
    this.id,
    required this.targetDate,
    this.status = ReviewGenerationJobStatus.pending,
    this.rawAssetsDump,
    this.attemptCount = 0,
    this.failureReason,
    this.processedAt,
    required this.createdAt,
  });

  ReviewGenerationJobEntity copyWith({
    int? id,
    ReviewGenerationJobStatus? status,
    String? rawAssetsDump,
    int? attemptCount,
    String? failureReason,
    DateTime? processedAt,
    DateTime? createdAt,
  }) {
    return ReviewGenerationJobEntity(
      id: id ?? this.id,
      targetDate: targetDate,
      status: status ?? this.status,
      rawAssetsDump: rawAssetsDump ?? this.rawAssetsDump,
      attemptCount: attemptCount ?? this.attemptCount,
      failureReason: failureReason ?? this.failureReason,
      processedAt: processedAt ?? this.processedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
