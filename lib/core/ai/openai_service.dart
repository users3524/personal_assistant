/// OpenAI API 实现。
library;

import 'package:dio/dio.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/ai/ai_prompts.dart';

class OpenAIService implements AIService {
  final Dio _dio;
  final String _model;
  final String _apiKey;

  OpenAIService({
    required String baseUrl,
    required String apiKey,
    String model = 'gpt-3.5-turbo',
    Dio? dio,
  })  : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
            )),
        _model = model,
        _apiKey = apiKey;

  @override
  Future<DailyReviewAIOutput> generateDailyReview({
    required String summary,
    String? highlights,
    String? improvements,
    required int energyLevel,
    required int moodLevel,
    required List<String> completedTitles,
    required int pattingMinutes,
  }) async {
    final prompt = AIPrompts.dailyReviewSystemPrompt(
      summary: summary,
      highlights: highlights,
      improvements: improvements,
      energyLevel: energyLevel,
      moodLevel: moodLevel,
      completedTitles: completedTitles,
      pattingMinutes: pattingMinutes,
    );

    final response = await _dio.post('/v1/chat/completions', data: {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': '你是一个温暖、专业的个人成长助手。'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': 500,
    });

    final text = response.data['choices'][0]['message']['content'] as String;

    // 解析返回文本
    return _parseDailyOutput(text);
  }

  @override
  Future<WeeklyReportAIOutput> generateWeeklyReport({
    required int weekNumber,
    required int year,
    required List<DailyReviewSummary> weekReviews,
  }) async {
    final reviewsText = weekReviews.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value;
      return '第$i天(${r.date}): 总结=${r.summary}, '
          '收获=${r.highlights ?? "无"}, '
          '不足=${r.improvements ?? "无"}, '
          '能量=${r.energyLevel}/5, 情绪=${r.moodLevel}/5, '
          '完成任务=${r.completedCount}个, 盘玩=${r.pattingMinutes}分钟';
    }).join('\n');

    final prompt = AIPrompts.weeklyReportSystemPrompt(
      weekReviewsText: reviewsText,
    );

    final response = await _dio.post('/v1/chat/completions', data: {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': '你是一个专业的职场复盘助手。'},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': 1000,
    });

    final text = response.data['choices'][0]['message']['content'] as String;

    return _parseWeeklyOutput(text);
  }

  @override
  Future<String> chat(String message) async {
    final response = await _dio.post('/v1/chat/completions', data: {
      'model': _model,
      'messages': [
        {'role': 'user', 'content': message},
      ],
      'temperature': 0.7,
      'max_tokens': 1000,
    });

    return response.data['choices'][0]['message']['content'] as String;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      await _dio.get('/v1/models');
      return true;
    } catch (_) {
      return false;
    }
  }

  DailyReviewAIOutput _parseDailyOutput(String text) {
    // 格式：评语：...\n改进建议：...\n情绪标签：...
    final parts = text.split('\n');
    String comment = '';
    String suggestion = '';
    String sentimentTag = '平稳';

    for (final part in parts) {
      if (part.contains('评语') || part.startsWith('1.')) {
        comment = part.replaceAll(RegExp(r'^[0-9.\s评语：]*'), '').trim();
      } else if (part.contains('建议') || part.startsWith('2.')) {
        suggestion = part.replaceAll(RegExp(r'^[0-9.\s改进建议：]*'), '').trim();
      } else if (part.contains('标签') || part.startsWith('3.')) {
        sentimentTag = part
            .replaceAll(RegExp(r'^[0-9.\s情绪标签：]*'), '')
            .trim();
        // 标准化标签
        if (sentimentTag.contains('高效')) sentimentTag = '高效';
        else if (sentimentTag.contains('焦虑')) sentimentTag = '焦虑';
        else if (sentimentTag.contains('疲惫')) sentimentTag = '疲惫';
        else sentimentTag = '平稳';
      }
    }

    return DailyReviewAIOutput(
      comment: comment.isNotEmpty ? comment : '做得很棒，继续保持！',
      suggestion: suggestion.isNotEmpty ? suggestion : '尝试每天给自己留出15分钟独处时间。',
      sentimentTag: sentimentTag,
    );
  }

  WeeklyReportAIOutput _parseWeeklyOutput(String text) {
    String overview = '';
    String highlights = '';
    String improvements = '';
    String nextWeekPlan = '';
    String currentSection = '';

    for (final line in text.split('\n')) {
      if (line.contains('本周概览') || line.contains('【本周概览】')) {
        currentSection = 'overview';
        continue;
      } else if (line.contains('本周亮点') || line.contains('【本周亮点】')) {
        currentSection = 'highlights';
        continue;
      } else if (line.contains('待改进') || line.contains('【待改进】')) {
        currentSection = 'improvements';
        continue;
      } else if (line.contains('下周计划') || line.contains('【下周计划】')) {
        currentSection = 'plan';
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      switch (currentSection) {
        case 'overview':
          overview += trimmed + '\n';
          break;
        case 'highlights':
          highlights += trimmed + '\n';
          break;
        case 'improvements':
          improvements += trimmed + '\n';
          break;
        case 'plan':
          nextWeekPlan += trimmed + '\n';
          break;
      }
    }

    return WeeklyReportAIOutput(
      overview: overview.trim(),
      highlights: highlights.trim(),
      improvements: improvements.trim(),
      nextWeekPlan: nextWeekPlan.trim(),
    );
  }
}
