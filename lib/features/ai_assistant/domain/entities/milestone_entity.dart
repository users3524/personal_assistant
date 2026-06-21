enum MilestoneSourceType {
  todo,
  dailyReview,
  pattingLog,
  manual;

  static MilestoneSourceType fromStorage(String value) {
    return switch (value) {
      'todo' => MilestoneSourceType.todo,
      'daily_review' => MilestoneSourceType.dailyReview,
      'patting_log' => MilestoneSourceType.pattingLog,
      'manual' => MilestoneSourceType.manual,
      _ => MilestoneSourceType.manual,
    };
  }

  String get storageValue {
    return switch (this) {
      MilestoneSourceType.todo => 'todo',
      MilestoneSourceType.dailyReview => 'daily_review',
      MilestoneSourceType.pattingLog => 'patting_log',
      MilestoneSourceType.manual => 'manual',
    };
  }
}

class MilestoneEntity {
  final int? id;
  final String title;
  final String? description;
  final DateTime occurredAt;
  final int importanceScore;
  final bool isAiGenerated;
  final bool isConfirmedByUser;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MilestoneEntity({
    this.id,
    required this.title,
    this.description,
    required this.occurredAt,
    this.importanceScore = 0,
    this.isAiGenerated = false,
    this.isConfirmedByUser = false,
    required this.createdAt,
    required this.updatedAt,
  });

  MilestoneEntity copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? occurredAt,
    int? importanceScore,
    bool? isAiGenerated,
    bool? isConfirmedByUser,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MilestoneEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      importanceScore: importanceScore ?? this.importanceScore,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isConfirmedByUser: isConfirmedByUser ?? this.isConfirmedByUser,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MilestoneRelationEntity {
  final int? id;
  final int milestoneId;
  final MilestoneSourceType sourceType;
  final int? sourceId;
  final String? note;
  final DateTime createdAt;

  const MilestoneRelationEntity({
    this.id,
    required this.milestoneId,
    required this.sourceType,
    this.sourceId,
    this.note,
    required this.createdAt,
  });

  MilestoneRelationEntity copyWith({
    int? id,
    int? milestoneId,
    MilestoneSourceType? sourceType,
    int? sourceId,
    String? note,
    DateTime? createdAt,
  }) {
    return MilestoneRelationEntity(
      id: id ?? this.id,
      milestoneId: milestoneId ?? this.milestoneId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProjectMilestoneRelationEntity {
  final int? id;
  final int projectId;
  final int milestoneId;
  final int sortOrder;
  final DateTime createdAt;

  const ProjectMilestoneRelationEntity({
    this.id,
    required this.projectId,
    required this.milestoneId,
    this.sortOrder = 0,
    required this.createdAt,
  });

  ProjectMilestoneRelationEntity copyWith({
    int? id,
    int? projectId,
    int? milestoneId,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return ProjectMilestoneRelationEntity(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      milestoneId: milestoneId ?? this.milestoneId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
