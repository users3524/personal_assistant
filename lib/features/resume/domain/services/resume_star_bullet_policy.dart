import '../entities/resume_entity.dart';

class ResumeStarFactPack {
  final String projectName;
  final String? role;
  final String? description;
  final List<String> techStack;
  final List<String> keyDeliverables;
  final List<String> badges;
  final List<String> milestoneSummaries;
  final List<String> todoDescriptions;

  const ResumeStarFactPack({
    required this.projectName,
    this.role,
    this.description,
    this.techStack = const [],
    this.keyDeliverables = const [],
    this.badges = const [],
    this.milestoneSummaries = const [],
    this.todoDescriptions = const [],
  });

  factory ResumeStarFactPack.fromProject(
    ProjectExperienceEntity project, {
    List<String> milestoneSummaries = const [],
    List<String> todoDescriptions = const [],
  }) {
    return ResumeStarFactPack(
      projectName: project.name,
      role: project.role,
      description: project.description,
      techStack: project.techStack,
      keyDeliverables: project.keyDeliverables,
      badges: project.badges,
      milestoneSummaries: milestoneSummaries,
      todoDescriptions: todoDescriptions,
    );
  }

  List<String> get allFacts {
    return [
      projectName,
      if (role != null) role!,
      if (description != null) description!,
      ...techStack,
      ...keyDeliverables,
      ...badges,
      ...milestoneSummaries,
      ...todoDescriptions,
    ].map((fact) => fact.trim()).where((fact) => fact.isNotEmpty).toList();
  }

  bool get hasFacts => allFacts.isNotEmpty;
}

class ResumeStarBulletResult {
  final List<String> bullets;
  final int droppedEmptyCount;
  final int droppedDuplicateCount;
  final int droppedUnsupportedFactCount;
  final int droppedOverflowCount;
  final int truncatedCount;

  const ResumeStarBulletResult({
    required this.bullets,
    required this.droppedEmptyCount,
    required this.droppedDuplicateCount,
    required this.droppedUnsupportedFactCount,
    required this.droppedOverflowCount,
    required this.truncatedCount,
  });

  bool get wasLimited =>
      droppedEmptyCount > 0 ||
      droppedDuplicateCount > 0 ||
      droppedUnsupportedFactCount > 0 ||
      droppedOverflowCount > 0 ||
      truncatedCount > 0;
}

class ResumeStarBulletPolicy {
  static const maxBullets = 3;
  static const defaultMaxBulletChars = 120;

  final int maxBulletChars;

  const ResumeStarBulletPolicy({this.maxBulletChars = defaultMaxBulletChars});

  String buildFactBoundPrompt(ResumeStarFactPack facts) {
    final buffer = StringBuffer();
    buffer.writeln('请基于以下本地事实生成项目经历 STAR bullet。');
    buffer.writeln('硬性规则：');
    buffer.writeln('1. 只能使用事实区出现的信息，不得编造百分比、用户量、公司主体或工具链。');
    buffer.writeln('2. 最多输出 3 条 bullet。');
    buffer.writeln('3. 只输出纯文本 bullet，不要输出排版、样式或布局建议。');
    buffer.writeln('');
    buffer.writeln('事实区：');
    for (final fact in facts.allFacts) {
      buffer.writeln('- $fact');
    }
    return buffer.toString().trimRight();
  }

  ResumeStarBulletResult sanitizeTextOutput({
    required ResumeStarFactPack facts,
    required String output,
  }) {
    return sanitizeBullets(
      facts: facts,
      rawBullets: output
          .split(RegExp(r'[\r\n]+'))
          .map(_stripBulletMarker)
          .where((line) => line.trim().isNotEmpty),
    );
  }

  ResumeStarBulletResult sanitizeBullets({
    required ResumeStarFactPack facts,
    required Iterable<String> rawBullets,
  }) {
    if (maxBulletChars <= 0) {
      throw ArgumentError.value(
        maxBulletChars,
        'maxBulletChars',
        'maxBulletChars must be positive.',
      );
    }

    final factIndex = _ResumeStarFactIndex(facts);
    final bullets = <String>[];
    final seen = <String>{};
    var droppedEmptyCount = 0;
    var droppedDuplicateCount = 0;
    var droppedUnsupportedFactCount = 0;
    var droppedOverflowCount = 0;
    var truncatedCount = 0;

    for (final raw in rawBullets) {
      final cleaned = _cleanBullet(raw);
      if (cleaned.isEmpty) {
        droppedEmptyCount++;
        continue;
      }

      if (!factIndex.supports(cleaned)) {
        droppedUnsupportedFactCount++;
        continue;
      }

      final dedupeKey = _normalizeCompact(cleaned);
      if (!seen.add(dedupeKey)) {
        droppedDuplicateCount++;
        continue;
      }

      if (bullets.length >= maxBullets) {
        droppedOverflowCount++;
        continue;
      }

      final clipped = _clipToChars(cleaned, maxBulletChars);
      if (clipped != cleaned) truncatedCount++;
      bullets.add(clipped);
    }

    return ResumeStarBulletResult(
      bullets: List.unmodifiable(bullets),
      droppedEmptyCount: droppedEmptyCount,
      droppedDuplicateCount: droppedDuplicateCount,
      droppedUnsupportedFactCount: droppedUnsupportedFactCount,
      droppedOverflowCount: droppedOverflowCount,
      truncatedCount: truncatedCount,
    );
  }

  String _cleanBullet(String raw) {
    return _stripBulletMarker(raw)
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'[`*_#>]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _clipToChars(String value, int maxChars) {
    final runes = value.runes.toList(growable: false);
    if (runes.length <= maxChars) return value;
    if (maxChars == 1) return '…';
    return '${String.fromCharCodes(runes.take(maxChars - 1))}…';
  }
}

class _ResumeStarFactIndex {
  static final _numberClaimPattern = RegExp(
    r'\d+(?:\.\d+)?\s*(?:%|％|万|千|百|个|人|次|元|小时|分钟|秒|天|周|月|年|条|项|倍|ms|s|k|K|m|M)',
  );

  static const _knownTechTerms = {
    'android',
    'angular',
    'aws',
    'dart',
    'docker',
    'drift',
    'firebase',
    'flutter',
    'go',
    'java',
    'kotlin',
    'kubernetes',
    'mysql',
    'node',
    'openai',
    'postgresql',
    'python',
    'react',
    'redis',
    'riverpod',
    'rust',
    'sqlite',
    'swift',
    'typescript',
    'vue',
  };

  static const _commonChineseAnchors = {
    '完成',
    '负责',
    '参与',
    '实现',
    '优化',
    '支持',
    '提升',
    '项目',
    '用户',
    '系统',
    '模块',
    '功能',
    '通过',
    '基于',
    '进行',
    '推动',
    '落地',
  };

  final String _normalizedFactText;
  final Set<String> _anchors;

  _ResumeStarFactIndex(ResumeStarFactPack facts)
    : _normalizedFactText = _normalizeCompact(facts.allFacts.join(' ')),
      _anchors = _buildAnchors(facts.allFacts);

  bool supports(String bullet) {
    if (_normalizedFactText.isEmpty) return false;
    final normalizedBullet = _normalizeCompact(bullet);
    if (normalizedBullet.isEmpty) return false;

    if (!_hasFactAnchor(normalizedBullet)) {
      return false;
    }
    if (!_numberClaimsAreSupported(normalizedBullet)) {
      return false;
    }
    if (!_techClaimsAreSupported(normalizedBullet)) {
      return false;
    }
    return true;
  }

  bool _hasFactAnchor(String normalizedBullet) {
    if (_normalizedFactText.contains(normalizedBullet)) return true;
    return _anchors.any(normalizedBullet.contains);
  }

  bool _numberClaimsAreSupported(String normalizedBullet) {
    for (final match in _numberClaimPattern.allMatches(normalizedBullet)) {
      if (!_normalizedFactText.contains(match.group(0)!)) {
        return false;
      }
    }
    return true;
  }

  bool _techClaimsAreSupported(String normalizedBullet) {
    for (final tech in _knownTechTerms) {
      if (normalizedBullet.contains(tech) &&
          !_normalizedFactText.contains(tech)) {
        return false;
      }
    }
    return true;
  }

  static Set<String> _buildAnchors(List<String> facts) {
    final anchors = <String>{};
    for (final fact in facts) {
      final normalized = _normalizeCompact(fact);
      if (normalized.length >= 2) anchors.add(normalized);

      for (final match in RegExp(
        r'[a-z][a-z0-9_+#.-]{1,}',
      ).allMatches(normalized)) {
        anchors.add(match.group(0)!);
      }

      final cjkMatches = RegExp(r'[\u4e00-\u9fff]{2,}').allMatches(normalized);
      for (final match in cjkMatches) {
        final text = match.group(0)!;
        for (var i = 0; i < text.length - 1; i++) {
          final bigram = text.substring(i, i + 2);
          if (!_commonChineseAnchors.contains(bigram)) {
            anchors.add(bigram);
          }
        }
      }
    }
    return anchors;
  }
}

String _stripBulletMarker(String value) {
  return value
      .trim()
      .replaceFirst(RegExp(r'^(?:[-*•●·]|\d+[.)、]|[（(]\d+[）)])\s*'), '')
      .trim();
}

String _normalizeCompact(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
}
