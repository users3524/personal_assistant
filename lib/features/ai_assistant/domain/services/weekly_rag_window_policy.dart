import 'dart:math' as math;

import '../../../../core/ai/prompt_builder.dart';

class WeeklyRagSlice {
  final String id;
  final String content;
  final double score;
  final String sourceType;
  final int? sourceId;
  final DateTime? occurredAt;

  const WeeklyRagSlice({
    required this.id,
    required this.content,
    required this.score,
    required this.sourceType,
    this.sourceId,
    this.occurredAt,
  });
}

class WindowedWeeklyRagSlice {
  final WeeklyRagSlice source;
  final String content;
  final int originalChars;
  final int clippedChars;
  final int estimatedTokens;
  final bool wasTruncated;

  const WindowedWeeklyRagSlice({
    required this.source,
    required this.content,
    required this.originalChars,
    required this.clippedChars,
    required this.estimatedTokens,
    required this.wasTruncated,
  });
}

class WeeklyRagWindow {
  final List<WindowedWeeklyRagSlice> slices;
  final String promptSection;
  final int topK;
  final int maxSliceChars;
  final int promptBudgetTokens;
  final int existingPromptTokens;
  final int estimatedRagTokens;
  final int totalEstimatedPromptTokens;
  final int droppedEmptyCount;
  final int droppedByTopKCount;
  final int droppedByBudgetCount;

  const WeeklyRagWindow({
    required this.slices,
    required this.promptSection,
    required this.topK,
    required this.maxSliceChars,
    required this.promptBudgetTokens,
    required this.existingPromptTokens,
    required this.estimatedRagTokens,
    required this.totalEstimatedPromptTokens,
    required this.droppedEmptyCount,
    required this.droppedByTopKCount,
    required this.droppedByBudgetCount,
  });

  bool get wasLimited =>
      droppedEmptyCount > 0 ||
      droppedByTopKCount > 0 ||
      droppedByBudgetCount > 0 ||
      slices.any((slice) => slice.wasTruncated);
}

class WeeklyRagWindowPolicy {
  static const maxTopK = 5;
  static const maxSliceCharsHardLimit = 400;
  static const defaultPromptBudgetTokens = 12000;
  static const maxPromptBudgetTokens = 12000;

  final int topK;
  final int maxSliceChars;
  final int promptBudgetTokens;
  final PromptBuilder _promptBuilder;

  const WeeklyRagWindowPolicy({
    this.topK = maxTopK,
    this.maxSliceChars = maxSliceCharsHardLimit,
    this.promptBudgetTokens = defaultPromptBudgetTokens,
    PromptBuilder promptBuilder = const PromptBuilder(),
  }) : _promptBuilder = promptBuilder;

  WeeklyRagWindow apply({
    required Iterable<WeeklyRagSlice> candidates,
    int existingPromptTokens = 0,
  }) {
    if (topK <= 0) {
      throw ArgumentError.value(topK, 'topK', 'topK must be positive.');
    }
    if (maxSliceChars <= 0) {
      throw ArgumentError.value(
        maxSliceChars,
        'maxSliceChars',
        'maxSliceChars must be positive.',
      );
    }
    if (promptBudgetTokens <= 0) {
      throw ArgumentError.value(
        promptBudgetTokens,
        'promptBudgetTokens',
        'promptBudgetTokens must be positive.',
      );
    }
    if (existingPromptTokens < 0) {
      throw ArgumentError.value(
        existingPromptTokens,
        'existingPromptTokens',
        'existingPromptTokens must not be negative.',
      );
    }

    final effectiveTopK = math.min(topK, maxTopK);
    final effectiveMaxSliceChars = math.min(
      maxSliceChars,
      maxSliceCharsHardLimit,
    );
    final effectivePromptBudgetTokens = math.min(
      promptBudgetTokens,
      maxPromptBudgetTokens,
    );

    final nonEmpty = <WeeklyRagSlice>[];
    var droppedEmptyCount = 0;
    for (final candidate in candidates) {
      if (candidate.content.trim().isEmpty) {
        droppedEmptyCount++;
      } else {
        nonEmpty.add(candidate);
      }
    }

    nonEmpty.sort(_compareSlices);
    final topCandidates = nonEmpty.take(effectiveTopK).toList(growable: false);
    final droppedByTopKCount = math.max(0, nonEmpty.length - effectiveTopK);

    final kept = <WindowedWeeklyRagSlice>[];
    var promptSection = '';
    var estimatedRagTokens = 0;
    var droppedByBudgetCount = 0;

    for (final candidate in topCandidates) {
      final windowed = _fitCandidate(
        candidate: candidate,
        currentSlices: kept,
        existingPromptTokens: existingPromptTokens,
        promptBudgetTokens: effectivePromptBudgetTokens,
        maxSliceChars: effectiveMaxSliceChars,
      );

      if (windowed == null) {
        droppedByBudgetCount++;
        continue;
      }

      kept.add(windowed);
      promptSection = _buildPromptSection(kept);
      estimatedRagTokens = _promptBuilder.estimateTokens(promptSection);
    }

    return WeeklyRagWindow(
      slices: List.unmodifiable(kept),
      promptSection: promptSection,
      topK: effectiveTopK,
      maxSliceChars: effectiveMaxSliceChars,
      promptBudgetTokens: effectivePromptBudgetTokens,
      existingPromptTokens: existingPromptTokens,
      estimatedRagTokens: estimatedRagTokens,
      totalEstimatedPromptTokens: existingPromptTokens + estimatedRagTokens,
      droppedEmptyCount: droppedEmptyCount,
      droppedByTopKCount: droppedByTopKCount,
      droppedByBudgetCount: droppedByBudgetCount,
    );
  }

  WindowedWeeklyRagSlice? _fitCandidate({
    required WeeklyRagSlice candidate,
    required List<WindowedWeeklyRagSlice> currentSlices,
    required int existingPromptTokens,
    required int promptBudgetTokens,
    required int maxSliceChars,
  }) {
    final trimmed = candidate.content.trim();
    final originalChars = _charCount(trimmed);
    final clipped = _clipToChars(trimmed, maxSliceChars);
    final firstAttempt = WindowedWeeklyRagSlice(
      source: candidate,
      content: clipped,
      originalChars: originalChars,
      clippedChars: _charCount(clipped),
      estimatedTokens: _promptBuilder.estimateTokens(clipped),
      wasTruncated: originalChars > _charCount(clipped),
    );
    if (_fitsBudget(
      [...currentSlices, firstAttempt],
      existingPromptTokens: existingPromptTokens,
      promptBudgetTokens: promptBudgetTokens,
    )) {
      return firstAttempt;
    }

    var low = 0;
    var high = _charCount(clipped);
    WindowedWeeklyRagSlice? best;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final content = _clipToChars(clipped, mid);
      final attempt = WindowedWeeklyRagSlice(
        source: candidate,
        content: content,
        originalChars: originalChars,
        clippedChars: _charCount(content),
        estimatedTokens: _promptBuilder.estimateTokens(content),
        wasTruncated: true,
      );
      if (content.trim().isNotEmpty &&
          _fitsBudget(
            [...currentSlices, attempt],
            existingPromptTokens: existingPromptTokens,
            promptBudgetTokens: promptBudgetTokens,
          )) {
        best = attempt;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }

  bool _fitsBudget(
    List<WindowedWeeklyRagSlice> slices, {
    required int existingPromptTokens,
    required int promptBudgetTokens,
  }) {
    final promptSection = _buildPromptSection(slices);
    final ragTokens = _promptBuilder.estimateTokens(promptSection);
    return existingPromptTokens + ragTokens <= promptBudgetTokens;
  }

  String _buildPromptSection(List<WindowedWeeklyRagSlice> slices) {
    if (slices.isEmpty) return '';
    final buffer = StringBuffer('相关历史：\n');
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sourceId = slice.source.sourceId == null
          ? ''
          : '#${slice.source.sourceId}';
      buffer.writeln(
        '${i + 1}. ${slice.source.sourceType}$sourceId '
        'score=${slice.source.score.toStringAsFixed(3)}',
      );
      buffer.writeln(slice.content);
    }
    return buffer.toString().trimRight();
  }

  int _compareSlices(WeeklyRagSlice a, WeeklyRagSlice b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;

    final aTime = a.occurredAt;
    final bTime = b.occurredAt;
    if (aTime != null && bTime != null) {
      final timeCompare = bTime.compareTo(aTime);
      if (timeCompare != 0) return timeCompare;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }

    return a.id.compareTo(b.id);
  }

  String _clipToChars(String value, int maxChars) {
    if (maxChars <= 0) return '';
    final runes = value.runes.toList(growable: false);
    if (runes.length <= maxChars) return value;
    return String.fromCharCodes(runes.take(maxChars));
  }

  int _charCount(String value) => value.runes.length;
}
