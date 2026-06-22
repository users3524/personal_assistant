/// Builds a clipped raw context JSON dump from the real local raw pack.
library;

import 'dart:collection';
import 'dart:convert';

import 'raw_context_clipper.dart';
import 'raw_context_pack_builder.dart';

class RawContextPackClipper {
  const RawContextPackClipper({
    required RawContextPackBuilder packBuilder,
    RawContextClipper clipper = const RawContextClipper(),
  }) : _packBuilder = packBuilder,
       _clipper = clipper;

  final RawContextPackBuilder _packBuilder;
  final RawContextClipper _clipper;

  Future<ClippedRawContextPack> build(DateTime targetDate) async {
    final pack = await _packBuilder.build(targetDate);
    final inputItems = pack.toClipperItems();
    final clipResult = _clipper.clip(inputItems);
    return ClippedRawContextPack(
      sourcePack: pack,
      inputItems: List.unmodifiable(inputItems),
      clipResult: clipResult,
    );
  }
}

class ClippedRawContextPack {
  const ClippedRawContextPack({
    required this.sourcePack,
    required this.inputItems,
    required this.clipResult,
  });

  final RawContextPack sourcePack;
  final List<RawContextItem> inputItems;
  final RawContextClipResult clipResult;

  Map<String, Object?> toJson() {
    final keptItems = _keptInOriginalOrder();
    final sections = _sectionsFrom(keptItems);
    return {
      'target_date': sourcePack.targetDate,
      'generated_at': sourcePack.generatedAt.toIso8601String(),
      'timezone_offset_minutes': sourcePack.timezoneOffsetMinutes,
      'clip': _clipMetadata(),
      'todos': sections.todos,
      'chat_turns': sections.chatTurns,
      'daily_review_draft': sections.dailyReviewDraft,
      'patting_logs': sections.pattingLogs,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  List<RawContextItem> _keptInOriginalOrder() {
    final kept = HashSet<RawContextItem>.identity()..addAll(clipResult.kept);
    return List.unmodifiable(inputItems.where(kept.contains));
  }

  Map<String, Object?> _clipMetadata() {
    return {
      'budget_chars': clipResult.budgetChars,
      'input_chars': clipResult.inputChars,
      'kept_chars': clipResult.usedChars,
      'dropped_chars': clipResult.inputChars - clipResult.usedChars,
      'input_count': inputItems.length,
      'kept_count': clipResult.kept.length,
      'dropped_count': clipResult.dropped.length,
      'was_clipped': clipResult.wasClipped,
      'kept_items': clipResult.kept.map(_itemMetadata).toList(),
      'dropped_items': clipResult.dropped
          .map(
            (item) =>
                _itemMetadata(item, reason: clipResult.dropReasonFor(item)),
          )
          .toList(),
    };
  }

  _RawContextSections _sectionsFrom(List<RawContextItem> items) {
    final todos = <Map<String, Object?>>[];
    final chatTurns = <Map<String, Object?>>[];
    final pattingLogs = <Map<String, Object?>>[];
    Map<String, Object?>? dailyReviewDraft;

    for (final item in items) {
      final decoded = _decodeItemMap(item);
      switch (item.source) {
        case RawContextSource.todo:
          todos.add(decoded);
          break;
        case RawContextSource.chatTurn:
          chatTurns.add(decoded);
          break;
        case RawContextSource.dailyReviewDraft:
          dailyReviewDraft ??= decoded;
          break;
        case RawContextSource.pattingLog:
          pattingLogs.add(decoded);
          break;
        case RawContextSource.manualNote:
          break;
      }
    }

    return _RawContextSections(
      todos: List.unmodifiable(todos),
      chatTurns: List.unmodifiable(chatTurns),
      dailyReviewDraft: dailyReviewDraft == null
          ? null
          : Map.unmodifiable(dailyReviewDraft),
      pattingLogs: List.unmodifiable(pattingLogs),
    );
  }

  Map<String, Object?> _decodeItemMap(RawContextItem item) {
    Object? decoded;
    try {
      decoded = jsonDecode(item.content);
    } on FormatException {
      decoded = item.content;
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return {'content': decoded};
  }

  Map<String, Object?> _itemMetadata(
    RawContextItem item, {
    RawContextDropReason? reason,
  }) {
    final decoded = _decodeItemMap(item);
    return {
      'source': _sourceName(item.source),
      'chars': item.charCount,
      'created_at': item.createdAt.toIso8601String(),
      'priority': item.priority,
      if (decoded['id'] != null) 'id': decoded['id'],
      if (decoded['title'] != null) 'title': decoded['title'],
      if (decoded['role'] != null) 'role': decoded['role'],
      if (decoded['date'] != null) 'date': decoded['date'],
      if (reason != null) 'reason': reason.storageValue,
    };
  }

  String _sourceName(RawContextSource source) {
    return switch (source) {
      RawContextSource.todo => 'todo',
      RawContextSource.chatTurn => 'chat_turn',
      RawContextSource.dailyReviewDraft => 'daily_review_draft',
      RawContextSource.pattingLog => 'patting_log',
      RawContextSource.manualNote => 'manual_note',
    };
  }
}

class _RawContextSections {
  const _RawContextSections({
    required this.todos,
    required this.chatTurns,
    required this.dailyReviewDraft,
    required this.pattingLogs,
  });

  final List<Map<String, Object?>> todos;
  final List<Map<String, Object?>> chatTurns;
  final Map<String, Object?>? dailyReviewDraft;
  final List<Map<String, Object?>> pattingLogs;
}
