import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/weekly_rag_window_policy.dart';

void main() {
  group('WeeklyRagWindowPolicy', () {
    test('keeps at most top five slices ordered by score and recency', () {
      final window = const WeeklyRagWindowPolicy(topK: 99).apply(
        candidates: [
          _slice('low', score: 0.1),
          _slice('old', score: 0.9, occurredAt: DateTime(2026, 6, 1)),
          _slice('new', score: 0.9, occurredAt: DateTime(2026, 6, 2)),
          _slice('third', score: 0.8),
          _slice('fourth', score: 0.7),
          _slice('fifth', score: 0.6),
          _slice('sixth', score: 0.5),
        ],
      );

      expect(window.topK, 5);
      expect(window.slices.map((slice) => slice.source.id), [
        'new',
        'old',
        'third',
        'fourth',
        'fifth',
      ]);
      expect(window.droppedByTopKCount, 2);
      expect(window.wasLimited, true);
    });

    test('clips every slice to at most four hundred chars', () {
      final window = const WeeklyRagWindowPolicy(maxSliceChars: 1000).apply(
        candidates: [_slice('long', content: List.filled(450, '复').join())],
      );

      expect(window.maxSliceChars, 400);
      expect(window.slices.single.originalChars, 450);
      expect(window.slices.single.clippedChars, 400);
      expect(window.slices.single.wasTruncated, true);
      expect(window.slices.single.content.runes.length, 400);
    });

    test('limits total rag section within the prompt token budget', () {
      final window =
          const WeeklyRagWindowPolicy(
            promptBudgetTokens: 80,
            maxSliceChars: 400,
          ).apply(
            existingPromptTokens: 20,
            candidates: [
              _slice(
                'first',
                score: 0.9,
                content: List.filled(200, '一').join(),
              ),
              _slice(
                'second',
                score: 0.8,
                content: List.filled(200, '二').join(),
              ),
              _slice(
                'third',
                score: 0.7,
                content: List.filled(200, '三').join(),
              ),
            ],
          );

      expect(window.promptBudgetTokens, 80);
      expect(window.totalEstimatedPromptTokens, lessThanOrEqualTo(80));
      expect(window.slices, isNotEmpty);
      expect(window.droppedByBudgetCount, greaterThan(0));
      expect(window.slices.first.wasTruncated, true);
    });

    test('drops empty slices before top-k and budget checks', () {
      final window = const WeeklyRagWindowPolicy(topK: 2).apply(
        candidates: [
          _slice('empty', score: 1, content: '   '),
          _slice('first', score: 0.9),
          _slice('second', score: 0.8),
          _slice('third', score: 0.7),
        ],
      );

      expect(window.slices.map((slice) => slice.source.id), [
        'first',
        'second',
      ]);
      expect(window.droppedEmptyCount, 1);
      expect(window.droppedByTopKCount, 1);
    });

    test('caps prompt budget at about twelve thousand tokens', () {
      final window = const WeeklyRagWindowPolicy(
        promptBudgetTokens: 20000,
      ).apply(candidates: [_slice('first')]);

      expect(window.promptBudgetTokens, 12000);
    });

    test('renders prompt section with source metadata', () {
      final window = const WeeklyRagWindowPolicy().apply(
        candidates: [
          _slice(
            'review-7',
            sourceType: 'daily_review',
            sourceId: 7,
            score: 0.91234,
            content: '完成了迁移验证',
          ),
        ],
      );

      expect(window.promptSection, contains('相关历史'));
      expect(window.promptSection, contains('daily_review#7 score=0.912'));
      expect(window.promptSection, contains('完成了迁移验证'));
      expect(window.estimatedRagTokens, greaterThan(0));
    });

    test('rejects invalid limits and existing prompt token counts', () {
      expect(
        () => const WeeklyRagWindowPolicy(topK: 0).apply(candidates: const []),
        throwsArgumentError,
      );
      expect(
        () => const WeeklyRagWindowPolicy(
          maxSliceChars: 0,
        ).apply(candidates: const []),
        throwsArgumentError,
      );
      expect(
        () => const WeeklyRagWindowPolicy(
          promptBudgetTokens: 0,
        ).apply(candidates: const []),
        throwsArgumentError,
      );
      expect(
        () => const WeeklyRagWindowPolicy().apply(
          existingPromptTokens: -1,
          candidates: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}

WeeklyRagSlice _slice(
  String id, {
  String? content,
  double score = 0.5,
  String sourceType = 'daily_review',
  int? sourceId,
  DateTime? occurredAt,
}) {
  return WeeklyRagSlice(
    id: id,
    content: content ?? '历史切片 $id',
    score: score,
    sourceType: sourceType,
    sourceId: sourceId,
    occurredAt: occurredAt,
  );
}
