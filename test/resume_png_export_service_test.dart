import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/resume/presentation/services/resume_png_export_service.dart';

void main() {
  group('ResumePngExportService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pa_resume_export_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes PNG bytes into a resume export temp directory', () async {
      final service = ResumePngExportService(
        temporaryDirectoryProvider: () async => tempDir,
        now: () => DateTime.fromMillisecondsSinceEpoch(12345),
      );

      final file = await service.writePngBytes(Uint8List.fromList([1, 2, 3]));

      expect(file.path, contains('resume_exports'));
      expect(file.path, endsWith('resume_12345.png'));
      expect(await file.readAsBytes(), [1, 2, 3]);
    });

    test('uses a suffix when the timestamp file already exists', () async {
      final exportDir = Directory('${tempDir.path}/resume_exports');
      await exportDir.create();
      await File('${exportDir.path}/resume_12345.png').writeAsBytes([9]);

      final service = ResumePngExportService(
        temporaryDirectoryProvider: () async => tempDir,
        now: () => DateTime.fromMillisecondsSinceEpoch(12345),
      );

      final file = await service.writePngBytes(Uint8List.fromList([4]));

      expect(file.path, endsWith('resume_12345_1.png'));
      expect(await file.readAsBytes(), [4]);
    });

    test('cleans stale resume PNG exports only', () async {
      final now = DateTime(2026, 6, 21, 12);
      final exportDir = Directory('${tempDir.path}/resume_exports');
      await exportDir.create();
      final staleResume = File('${exportDir.path}/resume_old.png');
      final freshResume = File('${exportDir.path}/resume_fresh.png');
      final otherFile = File('${exportDir.path}/other_old.png');
      await staleResume.writeAsBytes([1]);
      await freshResume.writeAsBytes([2]);
      await otherFile.writeAsBytes([3]);
      await staleResume.setLastModified(now.subtract(const Duration(days: 2)));
      await freshResume.setLastModified(now.subtract(const Duration(hours: 2)));
      await otherFile.setLastModified(now.subtract(const Duration(days: 2)));

      final service = ResumePngExportService(
        temporaryDirectoryProvider: () async => tempDir,
        now: () => now,
      );

      await service.writePngBytes(Uint8List.fromList([4]));

      expect(await staleResume.exists(), false);
      expect(await freshResume.exists(), true);
      expect(await otherFile.exists(), true);
    });

    test('rejects empty PNG bytes', () async {
      final service = ResumePngExportService(
        temporaryDirectoryProvider: () async => tempDir,
      );

      expect(
        () => service.writePngBytes(Uint8List(0)),
        throwsA(isA<ResumePngExportException>()),
      );
    });
  });
}
