import 'dart:convert';

import 'ai_service.dart';

class AIOutputParser {
  static const _fallbackNotice = 'AI 返回格式未完全符合预期，已保留原始内容供你手动整理。';

  AIOutputParser._();

  static DailyReviewAIOutput parseDaily(String text) {
    final raw = text.trim();
    String comment = '';
    String suggestion = '';
    String sentimentTag = '平稳';

    for (final line in raw.split('\n')) {
      final part = line.trim();
      if (part.isEmpty) continue;

      if (_isDailyCommentLine(part)) {
        comment = _stripDailyLabel(part, ['评语', 'AI评语', '复盘评语']);
      } else if (_isDailySuggestionLine(part)) {
        suggestion = _stripDailyLabel(part, ['改进建议', '建议', '行动建议']);
      } else if (_isDailyTagLine(part)) {
        sentimentTag = _normalizeSentimentTag(
          _stripDailyLabel(part, ['情绪标签', '标签', '状态标签']),
        );
      }
    }

    if (comment.isEmpty && suggestion.isEmpty) {
      return DailyReviewAIOutput(
        comment: raw.isEmpty
            ? 'AI 未返回可解析内容。'
            : '$_fallbackNotice\n${_truncate(raw, 600)}',
        suggestion: '请参考上方原始内容手动调整，或稍后重新生成一次。',
        sentimentTag: sentimentTag,
      );
    }

    return DailyReviewAIOutput(
      comment: comment.isNotEmpty ? comment : 'AI 返回内容缺少评语，请参考建议字段手动补全。',
      suggestion: suggestion.isNotEmpty
          ? suggestion
          : 'AI 返回内容缺少改进建议，请参考评语字段手动补全。',
      sentimentTag: sentimentTag,
    );
  }

  static DailyReviewAIOutput? tryParseDailyJson(String text) {
    try {
      final decoded = jsonDecode(_extractJsonObject(text.trim()));
      if (decoded is! Map<String, dynamic>) return null;

      final comment = _readJsonString(decoded, [
        'comment',
        'ai_comment',
        'aiComment',
        '评语',
      ]);
      final suggestion = _readJsonString(decoded, [
        'suggestion',
        'ai_suggestion',
        'aiSuggestion',
        '改进建议',
        '建议',
      ]);
      final sentimentTag = _readJsonString(decoded, [
        'sentiment_tag',
        'sentimentTag',
        '情绪标签',
      ]);

      if (comment == null || suggestion == null || sentimentTag == null) {
        return null;
      }

      return DailyReviewAIOutput(
        comment: comment,
        suggestion: suggestion,
        sentimentTag: _normalizeSentimentTag(sentimentTag),
      );
    } catch (_) {
      return null;
    }
  }

  static WeeklyReportAIOutput parseWeekly(String text) {
    final raw = text.trim();
    String overview = '';
    String highlights = '';
    String improvements = '';
    String nextWeekPlan = '';
    String currentSection = '';

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final section = _weeklySectionOf(trimmed);
      if (section != null) {
        currentSection = section;
        continue;
      }

      switch (currentSection) {
        case 'overview':
          overview = _appendLine(overview, trimmed);
          break;
        case 'highlights':
          highlights = _appendLine(highlights, trimmed);
          break;
        case 'improvements':
          improvements = _appendLine(improvements, trimmed);
          break;
        case 'plan':
          nextWeekPlan = _appendLine(nextWeekPlan, trimmed);
          break;
      }
    }

    if (overview.isEmpty &&
        highlights.isEmpty &&
        improvements.isEmpty &&
        nextWeekPlan.isEmpty) {
      final preserved = raw.isEmpty ? 'AI 未返回可解析内容。' : _truncate(raw, 1200);
      return WeeklyReportAIOutput(
        overview: _fallbackNotice,
        highlights: preserved,
        improvements: '• AI 未按「待改进」分段输出，请根据原始内容手动校准。',
        nextWeekPlan: '• AI 未按「下周计划」分段输出，请根据原始内容手动校准。',
      );
    }

    return WeeklyReportAIOutput(
      overview: overview.isNotEmpty
          ? overview.trim()
          : 'AI 返回内容缺少「本周概览」，请手动补全。',
      highlights: highlights.isNotEmpty
          ? highlights.trim()
          : '• AI 返回内容缺少「本周亮点」，请手动补全。',
      improvements: improvements.isNotEmpty
          ? improvements.trim()
          : '• AI 返回内容缺少「待改进」，请手动补全。',
      nextWeekPlan: nextWeekPlan.isNotEmpty
          ? nextWeekPlan.trim()
          : '• AI 返回内容缺少「下周计划」，请手动补全。',
    );
  }

  static bool _isDailyCommentLine(String line) {
    return line.contains('评语') || RegExp(r'^\s*1[.、)]').hasMatch(line);
  }

  static bool _isDailySuggestionLine(String line) {
    return line.contains('建议') || RegExp(r'^\s*2[.、)]').hasMatch(line);
  }

  static bool _isDailyTagLine(String line) {
    return line.contains('标签') || RegExp(r'^\s*3[.、)]').hasMatch(line);
  }

  static String _stripDailyLabel(String line, List<String> labels) {
    var result = line.replaceFirst(RegExp(r'^\s*[0-9]+[.、)]\s*'), '').trim();
    for (final label in labels) {
      result = result
          .replaceFirst(RegExp('^$label[：:]?\\s*'), '')
          .replaceFirst(RegExp('^【$label】\\s*'), '')
          .trim();
    }
    return result;
  }

  static String _normalizeSentimentTag(String raw) {
    if (raw.contains('高效')) return '高效';
    if (raw.contains('焦虑')) return '焦虑';
    if (raw.contains('疲惫')) return '疲惫';
    return '平稳';
  }

  static String _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end < start) return raw;
    return raw.substring(start, end + 1);
  }

  static String? _readJsonString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _weeklySectionOf(String line) {
    if (line.contains('本周概览')) return 'overview';
    if (line.contains('本周亮点')) return 'highlights';
    if (line.contains('待改进')) return 'improvements';
    if (line.contains('下周计划')) return 'plan';
    return null;
  }

  static String _appendLine(String current, String line) {
    if (current.isEmpty) return line;
    return '$current\n$line';
  }

  static String _truncate(String text, int maxRunes) {
    if (text.runes.length <= maxRunes) return text;
    return '${String.fromCharCodes(text.runes.take(maxRunes))}...';
  }
}
