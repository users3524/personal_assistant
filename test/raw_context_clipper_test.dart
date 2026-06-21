import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/ai/raw_context_clipper.dart';

void main() {
  group('RawContextClipper', () {
    test('keeps all items when they fit the default budget', () {
      const clipper = RawContextClipper();
      final items = [
        _item('todo', RawContextSource.todo),
        _item('chat', RawContextSource.chatTurn),
      ];

      final result = clipper.clip(items);

      expect(result.budgetChars, RawContextClipper.defaultBudgetChars);
      expect(result.kept.map((item) => item.content), ['todo', 'chat']);
      expect(result.dropped, isEmpty);
      expect(result.wasClipped, false);
    });

    test('prioritizes completed high priority todos over ordinary notes', () {
      const clipper = RawContextClipper(budgetChars: 12);
      final items = [
        _item('ordinary-note', RawContextSource.manualNote),
        _item(
          'ship-fix',
          RawContextSource.todo,
          priority: 1,
          isCompletedTodo: true,
        ),
        _item('later', RawContextSource.manualNote),
      ];

      final result = clipper.clip(items);

      expect(result.kept.map((item) => item.content), ['ship-fix']);
      expect(
        result.dropped.map((item) => item.content),
        containsAll(['ordinary-note', 'later']),
      );
      expect(result.wasClipped, true);
    });

    test('keeps coaching turns and noted patting logs before plain notes', () {
      const clipper = RawContextClipper(budgetChars: 30);
      final items = [
        _item('plain-offline-note', RawContextSource.manualNote),
        _item(
          'follow-up-question',
          RawContextSource.chatTurn,
          isCoachingTurn: true,
        ),
        _item(
          'patting-note',
          RawContextSource.pattingLog,
          hasPattingNote: true,
        ),
      ];

      final result = clipper.clip(items);

      expect(result.kept.map((item) => item.content), [
        'follow-up-question',
        'patting-note',
      ]);
      expect(result.dropped.single.content, 'plain-offline-note');
    });

    test('orders equally scored items by newest first', () {
      const clipper = RawContextClipper(budgetChars: 18);
      final items = [
        _item(
          'older',
          RawContextSource.manualNote,
          createdAt: DateTime(2026, 6, 20, 8),
        ),
        _item(
          'newer',
          RawContextSource.manualNote,
          createdAt: DateTime(2026, 6, 20, 9),
        ),
      ];

      final result = clipper.clip(items);

      expect(result.kept.map((item) => item.content), ['newer', 'older']);
    });

    test('drops empty items and handles zero budget', () {
      const clipper = RawContextClipper(budgetChars: 0);
      final items = [
        _item('', RawContextSource.todo),
        _item('content', RawContextSource.chatTurn),
      ];

      final result = clipper.clip(items);

      expect(result.kept, isEmpty);
      expect(result.dropped, items);
      expect(result.usedChars, 0);
      expect(result.wasClipped, true);
    });
  });
}

RawContextItem _item(
  String content,
  RawContextSource source, {
  int priority = 3,
  bool isCompletedTodo = false,
  bool isCoachingTurn = false,
  bool hasPattingNote = false,
  bool isOfflineNote = false,
  DateTime? createdAt,
}) {
  return RawContextItem(
    source: source,
    content: content,
    createdAt: createdAt ?? DateTime(2026, 6, 20, 12),
    priority: priority,
    isCompletedTodo: isCompletedTodo,
    isCoachingTurn: isCoachingTurn,
    hasPattingNote: hasPattingNote,
    isOfflineNote: isOfflineNote,
  );
}
