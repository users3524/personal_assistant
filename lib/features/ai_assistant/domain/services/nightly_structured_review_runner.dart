import '../../../../core/ai/ai_output_parser.dart';
import '../../../../core/ai/ai_service.dart';
import '../repositories/review_generation_job_store.dart';

enum NightlyReviewCallStage { initialJson, repairJson, plainTextFallback }

enum NightlyStructuredReviewStatus { success, failed }

class NightlyReviewModelRequest {
  final String targetDate;
  final NightlyReviewCallStage stage;
  final String prompt;
  final String rawAssetsDump;
  final String? previousOutput;
  final String? previousFailureReason;

  const NightlyReviewModelRequest({
    required this.targetDate,
    required this.stage,
    required this.prompt,
    required this.rawAssetsDump,
    this.previousOutput,
    this.previousFailureReason,
  });
}

class NightlyStructuredReviewResult {
  final NightlyStructuredReviewStatus status;
  final DailyReviewAIOutput? output;
  final int callsMade;
  final NightlyReviewCallStage? lastStage;
  final String? failureReason;
  final bool calibrationRequired;

  const NightlyStructuredReviewResult({
    required this.status,
    required this.callsMade,
    this.output,
    this.lastStage,
    this.failureReason,
    this.calibrationRequired = false,
  });

  bool get isSuccess => status == NightlyStructuredReviewStatus.success;
}

typedef NightlyReviewModelCaller =
    Future<String> Function(NightlyReviewModelRequest request);

typedef DailyReviewCalibrationMarker =
    Future<void> Function(
      DateTime date, {
      required bool calibrationRequired,
      DateTime? now,
    });

class NightlyStructuredReviewRunner {
  final ReviewGenerationJobStore _jobs;
  final NightlyReviewModelCaller _callModel;
  final DailyReviewCalibrationMarker _markCalibrationRequired;
  final DateTime Function() _now;

  const NightlyStructuredReviewRunner({
    required ReviewGenerationJobStore jobs,
    required NightlyReviewModelCaller callModel,
    required DailyReviewCalibrationMarker markCalibrationRequired,
    DateTime Function()? now,
  }) : _jobs = jobs,
       _callModel = callModel,
       _markCalibrationRequired = markCalibrationRequired,
       _now = now ?? DateTime.now;

  Future<NightlyStructuredReviewResult> run({
    required String targetDate,
    required String rawAssetsDump,
  }) async {
    final reviewDate = _parseTargetDate(targetDate);
    var job = await _jobs.getOrCreatePending(targetDate, now: _now());

    var callsMade = 0;
    String? previousOutput;
    String? failureReason;
    NightlyReviewCallStage? lastStage;

    while (true) {
      job = await _jobs.getByTargetDate(targetDate) ?? job;
      if (job.hasExhaustedStructuredCalls) {
        return _fail(
          targetDate: targetDate,
          reviewDate: reviewDate,
          rawAssetsDump: rawAssetsDump,
          callsMade: callsMade,
          lastStage: lastStage,
          failureReason: failureReason ?? '深夜 AI 生成已达到 3 次调用上限。',
        );
      }

      final stage = _stageForAttemptCount(job.attemptCount);
      lastStage = stage;
      await _jobs.incrementAttempt(targetDate, now: _now());
      callsMade++;

      final response = await _tryCallModel(
        NightlyReviewModelRequest(
          targetDate: targetDate,
          stage: stage,
          prompt: _buildPrompt(
            targetDate: targetDate,
            rawAssetsDump: rawAssetsDump,
            stage: stage,
            previousOutput: previousOutput,
            previousFailureReason: failureReason,
          ),
          rawAssetsDump: rawAssetsDump,
          previousOutput: previousOutput,
          previousFailureReason: failureReason,
        ),
      );

      if (response == null) {
        failureReason = '深夜 AI ${_stageLabel(stage)}调用失败。';
        continue;
      }

      if (stage == NightlyReviewCallStage.plainTextFallback) {
        if (response.trim().isEmpty) {
          failureReason = '纯文本降级返回空内容。';
          continue;
        }
        final output = AIOutputParser.parseDaily(response);
        await _jobs.markSuccess(
          targetDate,
          rawAssetsDump: rawAssetsDump,
          processedAt: _now(),
        );
        return NightlyStructuredReviewResult(
          status: NightlyStructuredReviewStatus.success,
          output: output,
          callsMade: callsMade,
          lastStage: stage,
        );
      }

      final output = AIOutputParser.tryParseDailyJson(response);
      if (output != null) {
        await _jobs.markSuccess(
          targetDate,
          rawAssetsDump: rawAssetsDump,
          processedAt: _now(),
        );
        return NightlyStructuredReviewResult(
          status: NightlyStructuredReviewStatus.success,
          output: output,
          callsMade: callsMade,
          lastStage: stage,
        );
      }

      previousOutput = response;
      failureReason = '${_stageLabel(stage)}返回内容不是可解析的日报 JSON。';
    }
  }

  Future<String?> _tryCallModel(NightlyReviewModelRequest request) async {
    try {
      return await _callModel(request);
    } catch (_) {
      return null;
    }
  }

  Future<NightlyStructuredReviewResult> _fail({
    required String targetDate,
    required DateTime reviewDate,
    required String rawAssetsDump,
    required int callsMade,
    required NightlyReviewCallStage? lastStage,
    required String failureReason,
  }) async {
    final processedAt = _now();
    await _jobs.markFailed(
      targetDate,
      rawAssetsDump: rawAssetsDump,
      failureReason: failureReason,
      processedAt: processedAt,
    );
    await _markCalibrationRequired(
      reviewDate,
      calibrationRequired: true,
      now: processedAt,
    );
    return NightlyStructuredReviewResult(
      status: NightlyStructuredReviewStatus.failed,
      callsMade: callsMade,
      lastStage: lastStage,
      failureReason: failureReason,
      calibrationRequired: true,
    );
  }

  NightlyReviewCallStage _stageForAttemptCount(int attemptCount) {
    if (attemptCount <= 0) return NightlyReviewCallStage.initialJson;
    if (attemptCount == 1) return NightlyReviewCallStage.repairJson;
    return NightlyReviewCallStage.plainTextFallback;
  }

  String _buildPrompt({
    required String targetDate,
    required String rawAssetsDump,
    required NightlyReviewCallStage stage,
    String? previousOutput,
    String? previousFailureReason,
  }) {
    return switch (stage) {
      NightlyReviewCallStage.initialJson => _initialJsonPrompt(
        targetDate,
        rawAssetsDump,
      ),
      NightlyReviewCallStage.repairJson => _repairJsonPrompt(
        targetDate,
        rawAssetsDump,
        previousOutput,
        previousFailureReason,
      ),
      NightlyReviewCallStage.plainTextFallback => _plainTextPrompt(
        targetDate,
        rawAssetsDump,
      ),
    };
  }

  String _initialJsonPrompt(String targetDate, String rawAssetsDump) {
    return '''
你是一个温暖、专业的个人成长助手。请根据以下深夜原始素材包，为 $targetDate 生成日报 AI 评语。

只返回一个 JSON 对象，不要 Markdown，不要代码块，不要额外解释。字段如下：
{
  "comment": "50-100 字的温暖复盘评语",
  "suggestion": "50-100 字的具体改进建议",
  "sentiment_tag": "高效/平稳/焦虑/疲惫"
}

原始素材包：
${_truncate(rawAssetsDump, 8000)}
''';
  }

  String _repairJsonPrompt(
    String targetDate,
    String rawAssetsDump,
    String? previousOutput,
    String? previousFailureReason,
  ) {
    return '''
上一轮 $targetDate 日报输出无法解析为指定 JSON。
失败原因：${previousFailureReason ?? '格式不符合 schema'}

请只修复格式并返回一个 JSON 对象，不要 Markdown，不要代码块，不要额外解释。必须包含：
{
  "comment": "50-100 字的温暖复盘评语",
  "suggestion": "50-100 字的具体改进建议",
  "sentiment_tag": "高效/平稳/焦虑/疲惫"
}

上一轮输出：
${_truncate(previousOutput ?? '无上一轮输出', 2000)}

原始素材包：
${_truncate(rawAssetsDump, 6000)}
''';
  }

  String _plainTextPrompt(String targetDate, String rawAssetsDump) {
    return '''
JSON 生成仍未成功。请为 $targetDate 生成纯文本日报反馈，只返回以下三行，不要 Markdown：
1. 评语：50-100 字
2. 改进建议：50-100 字
3. 情绪标签：高效/平稳/焦虑/疲惫

原始素材包：
${_truncate(rawAssetsDump, 8000)}
''';
  }

  String _stageLabel(NightlyReviewCallStage stage) {
    return switch (stage) {
      NightlyReviewCallStage.initialJson => '初次 JSON',
      NightlyReviewCallStage.repairJson => '格式修复',
      NightlyReviewCallStage.plainTextFallback => '纯文本降级',
    };
  }

  DateTime _parseTargetDate(String targetDate) {
    final parts = targetDate.split('-');
    if (parts.length != 3) {
      throw FormatException('targetDate must be YYYY-MM-DD', targetDate);
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final parsed = DateTime(year, month, day);
    final normalized =
        '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
    if (normalized != targetDate) {
      throw FormatException(
        'targetDate must be a valid local date',
        targetDate,
      );
    }
    return parsed;
  }

  String _truncate(String text, int maxRunes) {
    if (text.runes.length <= maxRunes) return text;
    return '${String.fromCharCodes(text.runes.take(maxRunes))}...';
  }
}
