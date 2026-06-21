class ResumeAiOutputSanitizedText {
  final String text;
  final bool wasChanged;

  const ResumeAiOutputSanitizedText({
    required this.text,
    required this.wasChanged,
  });
}

class ResumeAiOutputSanitizedList {
  final List<String> items;
  final int droppedEmptyCount;
  final int droppedInstructionCount;
  final int truncatedCount;

  const ResumeAiOutputSanitizedList({
    required this.items,
    required this.droppedEmptyCount,
    required this.droppedInstructionCount,
    required this.truncatedCount,
  });

  bool get wasChanged =>
      droppedEmptyCount > 0 ||
      droppedInstructionCount > 0 ||
      truncatedCount > 0;
}

class ResumeAiOutputSanitizer {
  static const defaultMaxTextChars = 600;
  static const defaultMaxItemChars = 160;
  static const defaultMaxItems = 10;

  final int maxTextChars;
  final int maxItemChars;
  final int maxItems;

  const ResumeAiOutputSanitizer({
    this.maxTextChars = defaultMaxTextChars,
    this.maxItemChars = defaultMaxItemChars,
    this.maxItems = defaultMaxItems,
  });

  ResumeAiOutputSanitizedText sanitizeText(dynamic output) {
    if (maxTextChars <= 0) {
      throw ArgumentError.value(
        maxTextChars,
        'maxTextChars',
        'maxTextChars must be positive.',
      );
    }
    if (output is! String) {
      throw ArgumentError.value(
        output,
        'output',
        'Resume AI text output must be a string.',
      );
    }

    final cleaned = _cleanText(output);
    final withoutInstructions = _dropInstructionLines(cleaned).join('\n');
    final clipped = _clipToChars(withoutInstructions, maxTextChars);
    return ResumeAiOutputSanitizedText(
      text: clipped,
      wasChanged: clipped != output,
    );
  }

  ResumeAiOutputSanitizedList sanitizeStringList(dynamic output) {
    if (maxItemChars <= 0) {
      throw ArgumentError.value(
        maxItemChars,
        'maxItemChars',
        'maxItemChars must be positive.',
      );
    }
    if (maxItems <= 0) {
      throw ArgumentError.value(
        maxItems,
        'maxItems',
        'maxItems must be positive.',
      );
    }
    if (output is! List || output.any((item) => item is! String)) {
      throw ArgumentError.value(
        output,
        'output',
        'Resume AI list output must be List<String>.',
      );
    }

    final items = <String>[];
    var droppedEmptyCount = 0;
    var droppedInstructionCount = 0;
    var truncatedCount = 0;

    for (final raw in output.cast<String>()) {
      if (items.length >= maxItems) {
        truncatedCount++;
        continue;
      }

      final cleaned = _cleanText(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.isEmpty) {
        droppedEmptyCount++;
        continue;
      }
      if (_isLayoutInstruction(cleaned)) {
        droppedInstructionCount++;
        continue;
      }

      final clipped = _clipToChars(cleaned, maxItemChars);
      if (clipped != cleaned) truncatedCount++;
      items.add(clipped);
    }

    return ResumeAiOutputSanitizedList(
      items: List.unmodifiable(items),
      droppedEmptyCount: droppedEmptyCount,
      droppedInstructionCount: droppedInstructionCount,
      truncatedCount: truncatedCount,
    );
  }

  List<String> _dropInstructionLines(String value) {
    final kept = <String>[];
    for (final rawLine in value.split(RegExp(r'[\r\n]+'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_isLayoutInstruction(line)) continue;
      kept.add(line);
    }
    return kept;
  }

  String _cleanText(String value) {
    return value
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .split(RegExp(r'[\r\n]+'))
        .map(_stripDecorativeMarkup)
        .join('\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  String _stripDecorativeMarkup(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^(?:[-*•●·]|\d+[.)、]|[（(]\d+[）)])\s*'), '')
        .replaceAll(RegExp(r'[`*_#]+'), '')
        .trim();
  }

  bool _isLayoutInstruction(String value) {
    final normalized = value.toLowerCase();
    return _layoutInstructionPatterns.any((pattern) {
      return pattern.hasMatch(normalized);
    });
  }

  String _clipToChars(String value, int maxChars) {
    final runes = value.runes.toList(growable: false);
    if (runes.length <= maxChars) return value;
    if (maxChars == 1) return '…';
    return '${String.fromCharCodes(runes.take(maxChars - 1))}…';
  }

  static final _layoutInstructionPatterns = [
    RegExp(r'\b(css|html|markdown|font|font-size|layout|style|color)\b'),
    RegExp(r'\b(grid|flex|margin|padding|border|background)\b'),
    RegExp(r'\b(page break|line height|template|theme)\b'),
    RegExp(r'字号|字体|颜色|色值|排版|布局|样式|间距|边距|分页|模板|主题'),
    RegExp(r'加粗|斜体|居中|左对齐|右对齐|双栏|单栏'),
  ];
}
