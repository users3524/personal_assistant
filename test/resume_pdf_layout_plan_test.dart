import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/resume/domain/services/resume_pdf_layout_plan.dart';

void main() {
  group('ResumePdfLayoutPlanner', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('uses deterministic A4 page constants and content area', () {
      const page = ResumePdfPageSpec();

      expect(page.widthPt, 595);
      expect(page.heightPt, 842);
      expect(page.marginPt, 42);
      expect(page.contentWidthPt, 511);
      expect(page.contentHeightPt, 758);
      expect(() => page.validate(), returnsNormally);
    });

    test('measures longer text as taller with TextPainter semantics', () {
      const planner = ResumePdfLayoutPlanner();

      final short = planner.measureTextHeight(
        text: '备份恢复',
        style: const ResumePdfTextStyleSpec(fontSizePt: 10),
        maxWidthPt: 120,
      );
      final long = planner.measureTextHeight(
        text: List.filled(40, '备份恢复').join(),
        style: const ResumePdfTextStyleSpec(fontSizePt: 10),
        maxWidthPt: 120,
      );

      expect(short, greaterThan(0));
      expect(long, greaterThan(short));
    });

    test('keeps protected blocks together by moving them to next page', () {
      const planner = ResumePdfLayoutPlanner(
        template: ResumePdfTemplateSpec(
          page: ResumePdfPageSpec(widthPt: 220, heightPt: 260, marginPt: 20),
        ),
      );

      final plan = planner.plan([
        _block('first', lines: 10),
        _block('second', lines: 10),
      ]);

      expect(plan.placedBlocks, hasLength(2));
      expect(plan.placedBlocks.first.pageIndex, 0);
      expect(plan.placedBlocks.last.pageIndex, 1);
      expect(
        plan.placedBlocks.last.overflowAction,
        ResumePdfOverflowAction.moveToNextPage,
      );
      expect(plan.usesOverflowSplit, false);
    });

    test('marks oversized blocks for split fallback', () {
      const planner = ResumePdfLayoutPlanner(
        template: ResumePdfTemplateSpec(
          page: ResumePdfPageSpec(widthPt: 220, heightPt: 160, marginPt: 20),
        ),
      );

      final plan = planner.plan([_block('oversized', lines: 80)]);

      expect(plan.placedBlocks.single.pageIndex, 0);
      expect(
        plan.placedBlocks.single.overflowAction,
        ResumePdfOverflowAction.splitOversizedBlock,
      );
      expect(plan.usesOverflowSplit, true);
    });

    test('measures bullet text using bullet width and indent', () {
      const planner = ResumePdfLayoutPlanner(
        template: ResumePdfTemplateSpec(
          page: ResumePdfPageSpec(widthPt: 240, heightPt: 300, marginPt: 20),
          bulletIndentPt: 30,
        ),
      );

      final withoutBullets = planner.measureBlock(_block('plain', lines: 2));
      final withBullets = planner.measureBlock(
        _block('bullet', lines: 2, bullets: [List.filled(20, '项目交付').join()]),
      );

      expect(withBullets.heightPt, greaterThan(withoutBullets.heightPt));
    });

    test('rejects invalid page and text measurement constraints', () {
      expect(
        () => const ResumePdfPageSpec(
          widthPt: 100,
          heightPt: 100,
          marginPt: 60,
        ).validate(),
        throwsArgumentError,
      );

      const planner = ResumePdfLayoutPlanner();
      expect(
        () => planner.measureTextHeight(
          text: 'invalid',
          style: const ResumePdfTextStyleSpec(fontSizePt: 10),
          maxWidthPt: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ResumePdfExportTestPlan', () {
    test('requires golden tolerance plus layout and semantic assertions', () {
      const plan = ResumePdfExportTestPlan();

      expect(plan.isReadyForPdfImplementation, true);
      expect(plan.usesGoldenTolerance, true);
      expect(plan.verifiesLayoutStructure, true);
      expect(plan.verifiesSemanticTree, true);
    });

    test('is not ready when relying on absolute golden pixels only', () {
      const plan = ResumePdfExportTestPlan(usesGoldenTolerance: false);

      expect(plan.isReadyForPdfImplementation, false);
    });
  });
}

ResumePdfContentBlock _block(
  String id, {
  int lines = 1,
  List<String> bullets = const [],
}) {
  return ResumePdfContentBlock(
    id: id,
    type: ResumePdfBlockType.project,
    title: '项目 $id',
    body: List.filled(lines, '本地优先个人助手').join('\n'),
    bullets: bullets,
  );
}
