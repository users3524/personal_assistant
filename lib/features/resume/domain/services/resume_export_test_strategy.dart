enum ResumeExportTarget { png, pdf }

class ResumeExportGoldenTolerance {
  final double maxDiffRate;
  final int maxDiffPixels;

  const ResumeExportGoldenTolerance({
    required this.maxDiffRate,
    required this.maxDiffPixels,
  });

  bool get allowsTolerance => maxDiffRate > 0 || maxDiffPixels > 0;

  void validate() {
    if (maxDiffRate < 0 || maxDiffRate > 1) {
      throw ArgumentError.value(
        maxDiffRate,
        'maxDiffRate',
        'maxDiffRate must be between 0 and 1.',
      );
    }
    if (maxDiffPixels < 0) {
      throw ArgumentError.value(
        maxDiffPixels,
        'maxDiffPixels',
        'maxDiffPixels must not be negative.',
      );
    }
  }
}

class ResumeExportLayoutAssertion {
  final String blockId;
  final bool assertsVisibleBounds;
  final bool assertsNoOverlap;
  final bool assertsStableOrder;

  const ResumeExportLayoutAssertion({
    required this.blockId,
    this.assertsVisibleBounds = true,
    this.assertsNoOverlap = true,
    this.assertsStableOrder = true,
  });

  bool get isStructural =>
      blockId.trim().isNotEmpty &&
      assertsVisibleBounds &&
      assertsNoOverlap &&
      assertsStableOrder;
}

class ResumeExportSemanticAssertion {
  final String text;
  final bool mustExist;

  const ResumeExportSemanticAssertion({
    required this.text,
    this.mustExist = true,
  });

  bool get isValid => text.trim().isNotEmpty && mustExist;
}

class ResumeExportTestStrategy {
  final ResumeExportTarget target;
  final ResumeExportGoldenTolerance goldenTolerance;
  final List<ResumeExportLayoutAssertion> layoutAssertions;
  final List<ResumeExportSemanticAssertion> semanticAssertions;
  final bool rejectsAbsolutePixelGolden;
  final bool coversExtremeText;

  const ResumeExportTestStrategy({
    required this.target,
    this.goldenTolerance = const ResumeExportGoldenTolerance(
      maxDiffRate: 0.01,
      maxDiffPixels: 250,
    ),
    this.layoutAssertions = const [],
    this.semanticAssertions = const [],
    this.rejectsAbsolutePixelGolden = true,
    this.coversExtremeText = true,
  });

  bool get isRobust {
    goldenTolerance.validate();
    return rejectsAbsolutePixelGolden &&
        coversExtremeText &&
        goldenTolerance.allowsTolerance &&
        layoutAssertions.isNotEmpty &&
        layoutAssertions.every((assertion) => assertion.isStructural) &&
        semanticAssertions.isNotEmpty &&
        semanticAssertions.every((assertion) => assertion.isValid);
  }
}
