import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();

class ResumePngExportException implements Exception {
  final String message;

  const ResumePngExportException(this.message);

  @override
  String toString() => message;
}

class ResumePngExportService {
  final TemporaryDirectoryProvider temporaryDirectoryProvider;
  final DateTime Function() now;
  final Duration tempFileRetention;
  final int maxPaintWaitFrames;

  ResumePngExportService({
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
    DateTime Function()? now,
    this.tempFileRetention = const Duration(days: 1),
    this.maxPaintWaitFrames = 10,
  }) : temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       now = now ?? DateTime.now;

  Future<File> export(GlobalKey repaintKey, {double pixelRatio = 3.0}) async {
    final boundary = await _readyBoundary(repaintKey);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw const ResumePngExportException('图片编码失败');
      }
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      return writePngBytes(Uint8List.fromList(bytes));
    } finally {
      image.dispose();
    }
  }

  Future<File> writePngBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const ResumePngExportException('导出图片为空');
    }

    final baseDir = await temporaryDirectoryProvider();
    final exportDir = Directory(p.join(baseDir.path, 'resume_exports'));
    await exportDir.create(recursive: true);
    await _cleanupOldExports(exportDir);

    final timestamp = now().millisecondsSinceEpoch;
    var file = File(p.join(exportDir.path, 'resume_$timestamp.png'));
    var suffix = 1;
    while (await file.exists()) {
      file = File(p.join(exportDir.path, 'resume_${timestamp}_$suffix.png'));
      suffix++;
    }

    await file.writeAsBytes(bytes);
    return file;
  }

  Future<RenderRepaintBoundary> _readyBoundary(GlobalKey repaintKey) async {
    for (var i = 0; i < maxPaintWaitFrames; i++) {
      final boundary = _findBoundary(repaintKey);
      if (!boundary.debugNeedsPaint) {
        if (boundary.size.isEmpty) {
          throw const ResumePngExportException('预览区域为空');
        }
        return boundary;
      }
      await WidgetsBinding.instance.endOfFrame;
    }

    final boundary = _findBoundary(repaintKey);
    if (boundary.debugNeedsPaint) {
      throw const ResumePngExportException('预览仍在绘制，请稍后重试');
    }
    if (boundary.size.isEmpty) {
      throw const ResumePngExportException('预览区域为空');
    }
    return boundary;
  }

  RenderRepaintBoundary _findBoundary(GlobalKey repaintKey) {
    final renderObject = repaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw const ResumePngExportException('无法获取预览区域');
    }
    return renderObject;
  }

  Future<void> _cleanupOldExports(Directory exportDir) async {
    final cutoff = now().subtract(tempFileRetention);
    await for (final entity in exportDir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path).toLowerCase();
      if (!name.startsWith('resume_') || !name.endsWith('.png')) continue;
      final modifiedAt = await entity.lastModified();
      if (modifiedAt.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }
}
