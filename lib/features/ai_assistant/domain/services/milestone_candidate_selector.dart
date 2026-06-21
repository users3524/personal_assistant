import '../entities/milestone_entity.dart';

enum MilestoneCandidateSignal {
  complexProblem,
  workProduct,
  delivery,
  phaseOutcome,
  measurableOutcome,
  routineCheckIn,
}

class MilestoneCandidate {
  final String title;
  final String? description;
  final DateTime occurredAt;
  final int score;
  final MilestoneSourceType sourceType;
  final int? sourceId;
  final Set<MilestoneCandidateSignal> signals;
  final String? relationNote;

  const MilestoneCandidate({
    required this.title,
    this.description,
    required this.occurredAt,
    required this.score,
    required this.sourceType,
    this.sourceId,
    this.signals = const {},
    this.relationNote,
  });
}

class SelectedMilestoneCandidate {
  final MilestoneCandidate candidate;
  final int importanceScore;

  const SelectedMilestoneCandidate({
    required this.candidate,
    required this.importanceScore,
  });

  MilestoneEntity toMilestoneEntity({required DateTime now}) {
    return MilestoneEntity(
      title: candidate.title.trim(),
      description: _blankToNull(candidate.description),
      occurredAt: candidate.occurredAt,
      importanceScore: importanceScore,
      isAiGenerated: true,
      isConfirmedByUser: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  MilestoneRelationEntity toRelation({
    required int milestoneId,
    required DateTime now,
  }) {
    return MilestoneRelationEntity(
      milestoneId: milestoneId,
      sourceType: candidate.sourceType,
      sourceId: candidate.sourceId,
      note: _blankToNull(candidate.relationNote),
      createdAt: now,
    );
  }
}

class MilestoneCandidateSelector {
  static const defaultMinimumScore = 80;
  static const defaultMaxPerDay = 2;

  final int minimumScore;
  final int maxPerDay;

  const MilestoneCandidateSelector({
    this.minimumScore = defaultMinimumScore,
    this.maxPerDay = defaultMaxPerDay,
  });

  List<SelectedMilestoneCandidate> selectForDay({
    required DateTime day,
    required List<MilestoneCandidate> candidates,
  }) {
    if (maxPerDay <= 0) return const [];

    final selected =
        candidates
            .where((candidate) => _isSameLocalDay(candidate.occurredAt, day))
            .where(_isEligible)
            .toList()
          ..sort(_compareCandidates);

    return List.unmodifiable(
      selected
          .take(maxPerDay)
          .map(
            (candidate) => SelectedMilestoneCandidate(
              candidate: candidate,
              importanceScore: _importanceScoreFor(candidate.score),
            ),
          ),
    );
  }

  bool _isEligible(MilestoneCandidate candidate) {
    return candidate.title.trim().isNotEmpty &&
        candidate.score >= minimumScore &&
        _hasValidSource(candidate) &&
        _hasHighValueSignal(candidate);
  }

  bool _hasValidSource(MilestoneCandidate candidate) {
    if (candidate.sourceType == MilestoneSourceType.manual) {
      return candidate.sourceId == null;
    }
    return candidate.sourceId != null;
  }

  bool _hasHighValueSignal(MilestoneCandidate candidate) {
    return candidate.signals.any(_isHighValueSignal);
  }

  bool _isHighValueSignal(MilestoneCandidateSignal signal) {
    return switch (signal) {
      MilestoneCandidateSignal.complexProblem ||
      MilestoneCandidateSignal.workProduct ||
      MilestoneCandidateSignal.delivery ||
      MilestoneCandidateSignal.phaseOutcome ||
      MilestoneCandidateSignal.measurableOutcome => true,
      MilestoneCandidateSignal.routineCheckIn => false,
    };
  }

  int _compareCandidates(MilestoneCandidate a, MilestoneCandidate b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;

    final signalCompare = _highValueSignalCount(
      b,
    ).compareTo(_highValueSignalCount(a));
    if (signalCompare != 0) return signalCompare;

    final timeCompare = b.occurredAt.compareTo(a.occurredAt);
    if (timeCompare != 0) return timeCompare;

    return a.title.trim().compareTo(b.title.trim());
  }

  int _highValueSignalCount(MilestoneCandidate candidate) {
    return candidate.signals.where(_isHighValueSignal).length;
  }

  int _importanceScoreFor(int score) {
    if (score >= 95) return 5;
    if (score >= 88) return 4;
    return 3;
  }

  bool _isSameLocalDay(DateTime value, DateTime day) {
    return value.year == day.year &&
        value.month == day.month &&
        value.day == day.day;
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
