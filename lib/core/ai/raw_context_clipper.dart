/// Priority clipper for nightly raw context packs.
library;

enum RawContextSource {
  todo,
  chatTurn,
  dailyReviewDraft,
  pattingLog,
  manualNote,
}

enum RawContextDropReason {
  emptyContent('empty_content'),
  budgetExceeded('budget_exceeded');

  final String storageValue;

  const RawContextDropReason(this.storageValue);
}

class RawContextItem {
  final RawContextSource source;
  final String content;
  final DateTime createdAt;
  final int priority;
  final bool isCompletedTodo;
  final bool isCoachingTurn;
  final bool hasPattingNote;
  final bool isOfflineNote;

  const RawContextItem({
    required this.source,
    required this.content,
    required this.createdAt,
    this.priority = 3,
    this.isCompletedTodo = false,
    this.isCoachingTurn = false,
    this.hasPattingNote = false,
    this.isOfflineNote = false,
  });

  int get charCount => content.runes.length;
}

class RawContextClipResult {
  final List<RawContextItem> kept;
  final List<RawContextItem> dropped;
  final Map<RawContextItem, RawContextDropReason> dropReasons;
  final int inputChars;
  final int usedChars;
  final int budgetChars;
  final bool wasClipped;

  const RawContextClipResult({
    required this.kept,
    required this.dropped,
    required this.dropReasons,
    required this.inputChars,
    required this.usedChars,
    required this.budgetChars,
    required this.wasClipped,
  });

  RawContextDropReason? dropReasonFor(RawContextItem item) {
    return dropReasons[item];
  }
}

class RawContextClipper {
  static const defaultBudgetChars = 8000;

  final int budgetChars;

  const RawContextClipper({this.budgetChars = defaultBudgetChars});

  RawContextClipResult clip(List<RawContextItem> items) {
    final inputChars = items.fold<int>(
      0,
      (total, item) => total + item.charCount,
    );

    if (budgetChars <= 0) {
      return RawContextClipResult(
        kept: const [],
        dropped: List.unmodifiable(items),
        dropReasons: Map.unmodifiable({
          for (final item in items) item: RawContextDropReason.budgetExceeded,
        }),
        inputChars: inputChars,
        usedChars: 0,
        budgetChars: budgetChars,
        wasClipped: items.isNotEmpty,
      );
    }

    final ordered = [...items]..sort(_comparePriority);
    final kept = <RawContextItem>[];
    final dropped = <RawContextItem>[];
    final dropReasons = <RawContextItem, RawContextDropReason>{};
    var usedChars = 0;

    for (final item in ordered) {
      if (item.content.trim().isEmpty) {
        dropped.add(item);
        dropReasons[item] = RawContextDropReason.emptyContent;
        continue;
      }
      final nextUsed = usedChars + item.charCount;
      if (nextUsed <= budgetChars) {
        kept.add(item);
        usedChars = nextUsed;
      } else {
        dropped.add(item);
        dropReasons[item] = RawContextDropReason.budgetExceeded;
      }
    }

    return RawContextClipResult(
      kept: List.unmodifiable(kept),
      dropped: List.unmodifiable(dropped),
      dropReasons: Map.unmodifiable(dropReasons),
      inputChars: inputChars,
      usedChars: usedChars,
      budgetChars: budgetChars,
      wasClipped: dropped.isNotEmpty,
    );
  }

  int _comparePriority(RawContextItem a, RawContextItem b) {
    final scoreCompare = _score(b).compareTo(_score(a));
    if (scoreCompare != 0) return scoreCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  int _score(RawContextItem item) {
    var score = 0;
    switch (item.source) {
      case RawContextSource.todo:
        score += 70;
        break;
      case RawContextSource.chatTurn:
        score += 50;
        break;
      case RawContextSource.pattingLog:
        score += 40;
        break;
      case RawContextSource.dailyReviewDraft:
        score += 35;
        break;
      case RawContextSource.manualNote:
        score += 20;
        break;
    }

    score += item.priority.clamp(1, 5) * 4;
    if (item.isCompletedTodo) score += 40;
    if (item.isCoachingTurn) score += 25;
    if (item.hasPattingNote) score += 20;
    if (item.isOfflineNote) score += 8;
    return score;
  }
}
