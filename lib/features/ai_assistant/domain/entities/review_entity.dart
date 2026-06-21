/// AI 复盘模块领域实体。
library;

class DailyReviewEntity {
  final int? id;
  final DateTime date;
  final String summary;
  final String? highlights;
  final String? improvements;
  final int energyLevel; // 1-5
  final int moodLevel; // 1-5
  final List<int> completedTodoIds;
  final int pattingMinutes;
  final String? aiComment;
  final String? aiSuggestion;
  final bool isAiGenerated;
  final bool isManuallyEdited;
  final bool calibrationRequired;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyReviewEntity({
    this.id,
    required this.date,
    required this.summary,
    this.highlights,
    this.improvements,
    this.energyLevel = 3,
    this.moodLevel = 3,
    this.completedTodoIds = const [],
    this.pattingMinutes = 0,
    this.aiComment,
    this.aiSuggestion,
    this.isAiGenerated = false,
    this.isManuallyEdited = false,
    this.calibrationRequired = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DailyReviewEntity copyWith({
    int? id,
    DateTime? date,
    String? summary,
    String? highlights,
    String? improvements,
    int? energyLevel,
    int? moodLevel,
    List<int>? completedTodoIds,
    int? pattingMinutes,
    String? aiComment,
    String? aiSuggestion,
    bool? isAiGenerated,
    bool? isManuallyEdited,
    bool? calibrationRequired,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyReviewEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      summary: summary ?? this.summary,
      highlights: highlights ?? this.highlights,
      improvements: improvements ?? this.improvements,
      energyLevel: energyLevel ?? this.energyLevel,
      moodLevel: moodLevel ?? this.moodLevel,
      completedTodoIds: completedTodoIds ?? this.completedTodoIds,
      pattingMinutes: pattingMinutes ?? this.pattingMinutes,
      aiComment: aiComment ?? this.aiComment,
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
      calibrationRequired: calibrationRequired ?? this.calibrationRequired,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WeeklyReportEntity {
  final int? id;
  final int weekNumber;
  final int year;
  final String overview;
  final String highlights;
  final String improvements;
  final String nextWeekPlan;
  final bool isAiGenerated;
  final bool isManuallyEdited;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WeeklyReportEntity({
    this.id,
    required this.weekNumber,
    required this.year,
    this.overview = '',
    this.highlights = '',
    this.improvements = '',
    this.nextWeekPlan = '',
    this.isAiGenerated = false,
    this.isManuallyEdited = false,
    required this.createdAt,
    required this.updatedAt,
  });

  WeeklyReportEntity copyWith({
    int? id,
    int? weekNumber,
    int? year,
    String? overview,
    String? highlights,
    String? improvements,
    String? nextWeekPlan,
    bool? isAiGenerated,
    bool? isManuallyEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeeklyReportEntity(
      id: id ?? this.id,
      weekNumber: weekNumber ?? this.weekNumber,
      year: year ?? this.year,
      overview: overview ?? this.overview,
      highlights: highlights ?? this.highlights,
      improvements: improvements ?? this.improvements,
      nextWeekPlan: nextWeekPlan ?? this.nextWeekPlan,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
