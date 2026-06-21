import 'dart:math' as math;

import 'package:flutter/painting.dart';

class ResumePdfPageSpec {
  final double widthPt;
  final double heightPt;
  final double marginPt;

  const ResumePdfPageSpec({
    this.widthPt = 595.0,
    this.heightPt = 842.0,
    this.marginPt = 42.0,
  });

  double get contentWidthPt => widthPt - marginPt * 2;
  double get contentHeightPt => heightPt - marginPt * 2;

  void validate() {
    if (widthPt <= 0 || heightPt <= 0) {
      throw ArgumentError('PDF page size must be positive.');
    }
    if (marginPt < 0 || marginPt * 2 >= widthPt || marginPt * 2 >= heightPt) {
      throw ArgumentError('PDF page margin leaves no usable content area.');
    }
  }
}

class ResumePdfTextStyleSpec {
  final double fontSizePt;
  final double lineHeight;
  final FontWeight fontWeight;

  const ResumePdfTextStyleSpec({
    required this.fontSizePt,
    this.lineHeight = 1.35,
    this.fontWeight = FontWeight.normal,
  });
}

class ResumePdfTemplateSpec {
  final ResumePdfPageSpec page;
  final ResumePdfTextStyleSpec titleStyle;
  final ResumePdfTextStyleSpec sectionTitleStyle;
  final ResumePdfTextStyleSpec bodyStyle;
  final ResumePdfTextStyleSpec bulletStyle;
  final double sectionGapPt;
  final double itemGapPt;
  final double bulletIndentPt;

  const ResumePdfTemplateSpec({
    this.page = const ResumePdfPageSpec(),
    this.titleStyle = const ResumePdfTextStyleSpec(
      fontSizePt: 20,
      lineHeight: 1.2,
      fontWeight: FontWeight.bold,
    ),
    this.sectionTitleStyle = const ResumePdfTextStyleSpec(
      fontSizePt: 13,
      fontWeight: FontWeight.bold,
    ),
    this.bodyStyle = const ResumePdfTextStyleSpec(fontSizePt: 10.5),
    this.bulletStyle = const ResumePdfTextStyleSpec(fontSizePt: 10),
    this.sectionGapPt = 12,
    this.itemGapPt = 6,
    this.bulletIndentPt = 12,
  });

  void validate() {
    page.validate();
    for (final style in [
      titleStyle,
      sectionTitleStyle,
      bodyStyle,
      bulletStyle,
    ]) {
      if (style.fontSizePt <= 0 || style.lineHeight <= 0) {
        throw ArgumentError(
          'PDF text style size and line height must be positive.',
        );
      }
    }
    if (sectionGapPt < 0 || itemGapPt < 0 || bulletIndentPt < 0) {
      throw ArgumentError('PDF spacing values must not be negative.');
    }
  }
}

enum ResumePdfBlockType {
  profile,
  summary,
  workExperience,
  education,
  skills,
  project,
}

enum ResumePdfOverflowAction { keepOnPage, moveToNextPage, splitOversizedBlock }

class ResumePdfContentBlock {
  final String id;
  final ResumePdfBlockType type;
  final String title;
  final String? body;
  final List<String> bullets;
  final bool protectFromSplit;

  const ResumePdfContentBlock({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.bullets = const [],
    this.protectFromSplit = true,
  });
}

class ResumePdfMeasuredBlock {
  final ResumePdfContentBlock block;
  final double heightPt;

  const ResumePdfMeasuredBlock({required this.block, required this.heightPt});
}

class ResumePdfPlacedBlock {
  final ResumePdfMeasuredBlock measuredBlock;
  final int pageIndex;
  final double yOffsetPt;
  final ResumePdfOverflowAction overflowAction;

  const ResumePdfPlacedBlock({
    required this.measuredBlock,
    required this.pageIndex,
    required this.yOffsetPt,
    required this.overflowAction,
  });
}

class ResumePdfLayoutPlan {
  final ResumePdfTemplateSpec template;
  final List<ResumePdfPlacedBlock> placedBlocks;
  final int pageCount;
  final bool usesOverflowSplit;

  const ResumePdfLayoutPlan({
    required this.template,
    required this.placedBlocks,
    required this.pageCount,
    required this.usesOverflowSplit,
  });
}

class ResumePdfLayoutPlanner {
  final ResumePdfTemplateSpec template;

  const ResumePdfLayoutPlanner({this.template = const ResumePdfTemplateSpec()});

  ResumePdfLayoutPlan plan(List<ResumePdfContentBlock> blocks) {
    template.validate();
    final placed = <ResumePdfPlacedBlock>[];
    var currentPage = 0;
    var yOffset = 0.0;
    var usesOverflowSplit = false;

    for (final block in blocks) {
      final measured = measureBlock(block);
      var action = ResumePdfOverflowAction.keepOnPage;

      if (measured.heightPt > template.page.contentHeightPt) {
        action = ResumePdfOverflowAction.splitOversizedBlock;
        usesOverflowSplit = true;
        if (yOffset > 0) {
          currentPage++;
          yOffset = 0;
        }
      } else if (yOffset > 0 &&
          yOffset + measured.heightPt > template.page.contentHeightPt) {
        action = block.protectFromSplit
            ? ResumePdfOverflowAction.moveToNextPage
            : ResumePdfOverflowAction.splitOversizedBlock;
        if (block.protectFromSplit) {
          currentPage++;
          yOffset = 0;
        } else {
          usesOverflowSplit = true;
        }
      }

      placed.add(
        ResumePdfPlacedBlock(
          measuredBlock: measured,
          pageIndex: currentPage,
          yOffsetPt: yOffset,
          overflowAction: action,
        ),
      );

      yOffset += measured.heightPt + template.itemGapPt;
      if (yOffset > template.page.contentHeightPt &&
          action != ResumePdfOverflowAction.keepOnPage) {
        currentPage++;
        yOffset = 0;
      }
    }

    return ResumePdfLayoutPlan(
      template: template,
      placedBlocks: List.unmodifiable(placed),
      pageCount: placed.isEmpty
          ? 0
          : placed.map((block) => block.pageIndex).reduce(math.max) + 1,
      usesOverflowSplit: usesOverflowSplit,
    );
  }

  ResumePdfMeasuredBlock measureBlock(ResumePdfContentBlock block) {
    final width = template.page.contentWidthPt;
    var height = 0.0;
    height += measureTextHeight(
      text: block.title,
      style: template.sectionTitleStyle,
      maxWidthPt: width,
    );

    final body = block.body?.trim();
    if (body != null && body.isNotEmpty) {
      height += template.itemGapPt;
      height += measureTextHeight(
        text: body,
        style: template.bodyStyle,
        maxWidthPt: width,
      );
    }

    for (final bullet in block.bullets.where(
      (item) => item.trim().isNotEmpty,
    )) {
      height += template.itemGapPt / 2;
      height += measureTextHeight(
        text: bullet,
        style: template.bulletStyle,
        maxWidthPt: width - template.bulletIndentPt,
      );
    }

    height += template.sectionGapPt;
    return ResumePdfMeasuredBlock(block: block, heightPt: height);
  }

  double measureTextHeight({
    required String text,
    required ResumePdfTextStyleSpec style,
    required double maxWidthPt,
  }) {
    if (maxWidthPt <= 0) {
      throw ArgumentError.value(
        maxWidthPt,
        'maxWidthPt',
        'maxWidthPt must be positive.',
      );
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: style.fontSizePt,
          height: style.lineHeight,
          fontWeight: style.fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidthPt);
    return painter.height;
  }
}

class ResumePdfExportTestPlan {
  final bool verifiesPdfBytes;
  final bool verifiesA4PageSize;
  final bool verifiesKeyTextPresence;
  final bool verifiesExtremeTextDoesNotThrow;
  final bool usesGoldenTolerance;
  final bool verifiesLayoutStructure;
  final bool verifiesSemanticTree;

  const ResumePdfExportTestPlan({
    this.verifiesPdfBytes = true,
    this.verifiesA4PageSize = true,
    this.verifiesKeyTextPresence = true,
    this.verifiesExtremeTextDoesNotThrow = true,
    this.usesGoldenTolerance = true,
    this.verifiesLayoutStructure = true,
    this.verifiesSemanticTree = true,
  });

  bool get isReadyForPdfImplementation =>
      verifiesPdfBytes &&
      verifiesA4PageSize &&
      verifiesKeyTextPresence &&
      verifiesExtremeTextDoesNotThrow &&
      usesGoldenTolerance &&
      verifiesLayoutStructure &&
      verifiesSemanticTree;
}
