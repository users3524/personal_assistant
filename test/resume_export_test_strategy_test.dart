import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/resume/domain/services/resume_export_test_strategy.dart';

void main() {
  group('ResumeExportTestStrategy', () {
    test(
      'requires golden tolerance, layout structure and semantic assertions',
      () {
        const strategy = ResumeExportTestStrategy(
          target: ResumeExportTarget.png,
          layoutAssertions: [
            ResumeExportLayoutAssertion(blockId: 'profile'),
            ResumeExportLayoutAssertion(blockId: 'projects'),
          ],
          semanticAssertions: [
            ResumeExportSemanticAssertion(text: '张三'),
            ResumeExportSemanticAssertion(text: '项目经历'),
          ],
        );

        expect(strategy.isRobust, true);
        expect(strategy.goldenTolerance.allowsTolerance, true);
      },
    );

    test('rejects absolute one pixel golden comparisons', () {
      const strategy = ResumeExportTestStrategy(
        target: ResumeExportTarget.pdf,
        goldenTolerance: ResumeExportGoldenTolerance(
          maxDiffRate: 0,
          maxDiffPixels: 0,
        ),
        layoutAssertions: [ResumeExportLayoutAssertion(blockId: 'profile')],
        semanticAssertions: [ResumeExportSemanticAssertion(text: '张三')],
      );

      expect(strategy.goldenTolerance.allowsTolerance, false);
      expect(strategy.isRobust, false);
    });

    test('requires structural layout assertions', () {
      const strategy = ResumeExportTestStrategy(
        target: ResumeExportTarget.png,
        layoutAssertions: [
          ResumeExportLayoutAssertion(
            blockId: 'projects',
            assertsNoOverlap: false,
          ),
        ],
        semanticAssertions: [ResumeExportSemanticAssertion(text: '项目经历')],
      );

      expect(strategy.isRobust, false);
    });

    test('requires semantic text assertions', () {
      const missingSemantic = ResumeExportTestStrategy(
        target: ResumeExportTarget.pdf,
        layoutAssertions: [ResumeExportLayoutAssertion(blockId: 'profile')],
      );
      const blankSemantic = ResumeExportTestStrategy(
        target: ResumeExportTarget.pdf,
        layoutAssertions: [ResumeExportLayoutAssertion(blockId: 'profile')],
        semanticAssertions: [ResumeExportSemanticAssertion(text: '  ')],
      );

      expect(missingSemantic.isRobust, false);
      expect(blankSemantic.isRobust, false);
    });

    test('requires extreme text coverage', () {
      const strategy = ResumeExportTestStrategy(
        target: ResumeExportTarget.png,
        coversExtremeText: false,
        layoutAssertions: [ResumeExportLayoutAssertion(blockId: 'profile')],
        semanticAssertions: [ResumeExportSemanticAssertion(text: '张三')],
      );

      expect(strategy.isRobust, false);
    });

    test('validates tolerance ranges', () {
      expect(
        () => const ResumeExportGoldenTolerance(
          maxDiffRate: 1.1,
          maxDiffPixels: 1,
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const ResumeExportGoldenTolerance(
          maxDiffRate: 0.01,
          maxDiffPixels: -1,
        ).validate(),
        throwsArgumentError,
      );
    });
  });
}
