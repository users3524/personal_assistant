/// OpenAI API 实现。
library;

import 'package:dio/dio.dart';

import '../../../core/ai/ai_output_parser.dart';
import '../../../core/ai/llm_strategy_config.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ai/prompt_builder.dart';

class OpenAIService implements AIService {
  final Dio _dio;
  final String _model;
  final PromptBuilder _promptBuilder;

  OpenAIService({
    required String baseUrl,
    required String apiKey,
    String model = 'gpt-3.5-turbo',
    LLMStrategyConfig strategy = const LLMStrategyConfig(),
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(seconds: 60),
               headers: {
                 'Content-Type': 'application/json',
                 'Authorization': 'Bearer $apiKey',
               },
             ),
           ),
       _model = model,
       _promptBuilder = PromptBuilder(strategy: strategy);

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
    final prompt = _promptBuilder.buildDailyReviewPrompt(
      summary: summary,
      highlights: highlights,
      improvements: improvements,
      energyLevel: energyLevel,
      moodLevel: moodLevel,
      completedTitles: completedTitles,
      pattingMinutes: pattingMinutes,
    );

    final response = await _dio.post(
      '/v1/chat/completions',
      data: {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': '你是一个温暖、专业的个人成长助手。'},
          {'role': 'user', 'content': prompt.prompt},
        ],
        'temperature': 0.7,
        'max_tokens': prompt.maxOutputTokens,
      },
    );

    final text = response.data['choices'][0]['message']['content'] as String;

    return AIOutputParser.parseDaily(text);
  }

  @override
  Future<WeeklyReportAIOutput> generateWeeklyReport({
    required int weekNumber,
    required int year,
    required List<DailyReviewSummary> weekReviews,
  }) async {
    final reviewsText = weekReviews
        .asMap()
        .entries
        .map((entry) {
          final i = entry.key + 1;
          final r = entry.value;
          return '第$i天(${r.date}): 总结=${r.summary}, '
              '收获=${r.highlights ?? "无"}, '
              '不足=${r.improvements ?? "无"}, '
              '能量=${r.energyLevel}/5, 情绪=${r.moodLevel}/5, '
              '完成任务=${r.completedCount}个, 盘玩=${r.pattingMinutes}分钟';
        })
        .join('\n');

    final prompt = _promptBuilder.buildWeeklyReportPrompt(
      weekReviewsText: reviewsText,
    );

    final response = await _dio.post(
      '/v1/chat/completions',
      data: {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': '你是一个专业的职场复盘助手。'},
          {'role': 'user', 'content': prompt.prompt},
        ],
        'temperature': 0.7,
        'max_tokens': prompt.maxOutputTokens,
      },
    );

    final text = response.data['choices'][0]['message']['content'] as String;

    return AIOutputParser.parseWeekly(text);
  }

  @override
  Future<String> chat(String message) async {
    final prompt = _promptBuilder.buildChatPrompt(message);
    final response = await _dio.post(
      '/v1/chat/completions',
      data: {
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt.prompt},
        ],
        'temperature': 0.7,
        'max_tokens': prompt.maxOutputTokens,
      },
    );

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
}
