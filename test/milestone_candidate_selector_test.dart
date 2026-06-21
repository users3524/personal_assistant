import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/entities/milestone_entity.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/milestone_candidate_selector.dart';

void main() {
  group('MilestoneCandidateSelector', () {
    test('allows zero milestones when no candidate reaches the gate', () {
      const selector = MilestoneCandidateSelector();
      final selected = selector.selectForDay(
        day: DateTime(2026, 6, 20),
        candidates: [
          _candidate(
            'ordinary progress',
            score: 79,
            signals: {MilestoneCandidateSignal.delivery},
          ),
          _candidate(
            'daily check-in',
            score: 98,
            signals: {MilestoneCandidateSignal.routineCheckIn},
          ),
        ],
      );

      expect(selected, isEmpty);
    });

    test('keeps at most two candidates for one day', () {
      const selector = MilestoneCandidateSelector();
      final selected = selector.selectForDay(
        day: DateTime(2026, 6, 20),
        candidates: [
          _candidate(
            'third',
            score: 88,
            signals: {MilestoneCandidateSignal.phaseOutcome},
          ),
          _candidate(
            'first',
            score: 96,
            signals: {MilestoneCandidateSignal.delivery},
          ),
          _candidate(
            'second',
            score: 92,
            signals: {MilestoneCandidateSignal.complexProblem},
          ),
        ],
      );

      expect(selected.map((item) => item.candidate.title), ['first', 'second']);
      expect(selected.map((item) => item.importanceScore), [5, 4]);
    });

    test('orders tied candidates by signal count and newest time', () {
      const selector = MilestoneCandidateSelector();
      final selected = selector.selectForDay(
        day: DateTime(2026, 6, 20),
        candidates: [
          _candidate(
            'older-single-signal',
            score: 90,
            occurredAt: DateTime(2026, 6, 20, 9),
            signals: {MilestoneCandidateSignal.delivery},
          ),
          _candidate(
            'newer-single-signal',
            score: 90,
            occurredAt: DateTime(2026, 6, 20, 18),
            signals: {MilestoneCandidateSignal.delivery},
          ),
          _candidate(
            'two-signals',
            score: 90,
            occurredAt: DateTime(2026, 6, 20, 10),
            signals: {
              MilestoneCandidateSignal.complexProblem,
              MilestoneCandidateSignal.delivery,
            },
          ),
        ],
      );

      expect(selected.map((item) => item.candidate.title), [
        'two-signals',
        'newer-single-signal',
      ]);
    });

    test('ignores candidates outside the target local day', () {
      const selector = MilestoneCandidateSelector();
      final selected = selector.selectForDay(
        day: DateTime(2026, 6, 20),
        candidates: [
          _candidate(
            'previous day',
            score: 99,
            occurredAt: DateTime(2026, 6, 19, 23, 59),
            signals: {MilestoneCandidateSignal.delivery},
          ),
          _candidate(
            'target day',
            score: 90,
            occurredAt: DateTime(2026, 6, 20),
            signals: {MilestoneCandidateSignal.delivery},
          ),
        ],
      );

      expect(selected.single.candidate.title, 'target day');
    });

    test('builds milestone and relation drafts from selected candidates', () {
      const selector = MilestoneCandidateSelector();
      final now = DateTime(2026, 6, 21, 2);
      final selected = selector
          .selectForDay(
            day: DateTime(2026, 6, 20),
            candidates: [
              _candidate(
                '  shipped review engine  ',
                description: '  nightly runner and tests  ',
                score: 95,
                sourceType: MilestoneSourceType.dailyReview,
                sourceId: 7,
                relationNote: '  review evidence  ',
                signals: {MilestoneCandidateSignal.delivery},
              ),
            ],
          )
          .single;

      final milestone = selected.toMilestoneEntity(now: now);
      final relation = selected.toRelation(milestoneId: 42, now: now);

      expect(milestone.title, 'shipped review engine');
      expect(milestone.description, 'nightly runner and tests');
      expect(milestone.importanceScore, 5);
      expect(milestone.isAiGenerated, true);
      expect(milestone.isConfirmedByUser, false);
      expect(relation.milestoneId, 42);
      expect(relation.sourceType, MilestoneSourceType.dailyReview);
      expect(relation.sourceId, 7);
      expect(relation.note, 'review evidence');
    });

    test('requires traceable source ids except for manual candidates', () {
      const selector = MilestoneCandidateSelector();
      final selected = selector.selectForDay(
        day: DateTime(2026, 6, 20),
        candidates: [
          MilestoneCandidate(
            title: 'missing todo source id',
            occurredAt: DateTime(2026, 6, 20, 12),
            score: 95,
            sourceType: MilestoneSourceType.todo,
            signals: const {MilestoneCandidateSignal.delivery},
          ),
          _candidate(
            'manual source',
            score: 95,
            sourceType: MilestoneSourceType.manual,
            sourceId: null,
            signals: {MilestoneCandidateSignal.delivery},
          ),
        ],
      );

      expect(selected.single.candidate.title, 'manual source');
    });
  });
}

MilestoneCandidate _candidate(
  String title, {
  String? description,
  DateTime? occurredAt,
  int score = 90,
  MilestoneSourceType sourceType = MilestoneSourceType.todo,
  int? sourceId = 1,
  Set<MilestoneCandidateSignal> signals = const {},
  String? relationNote,
}) {
  return MilestoneCandidate(
    title: title,
    description: description,
    occurredAt: occurredAt ?? DateTime(2026, 6, 20, 12),
    score: score,
    sourceType: sourceType,
    sourceId: sourceId,
    signals: signals,
    relationNote: relationNote,
  );
}
