import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/ai_assistant/domain/services/vector_data_codec.dart';

void main() {
  group('VectorDataCodec', () {
    const codec = VectorDataCodec();

    test('encodes normalized float32 little-endian vectors', () {
      final bytes = codec.encodeNormalized([3, 4]);

      expect(bytes.length, 8);
      final data = ByteData.view(bytes.buffer);
      expect(data.getFloat32(0, Endian.little), closeTo(0.6, 0.000001));
      expect(data.getFloat32(4, Endian.little), closeTo(0.8, 0.000001));
      expect(data.getFloat32(0, Endian.big), isNot(closeTo(0.6, 0.000001)));
    });

    test('decodes float32 little-endian vectors by dimension', () {
      final bytes = codec.encodeNormalized([0, 10, 0]);

      final decoded = codec.decode(bytes, dimension: 3);

      expect(decoded, [0, 1, 0]);
    });

    test('rejects empty, zero and invalid vectors', () {
      expect(() => codec.encodeNormalized(const []), throwsArgumentError);
      expect(() => codec.encodeNormalized(const [0, 0]), throwsArgumentError);
      expect(() => codec.encodeNormalized([double.nan]), throwsArgumentError);
      expect(
        () => codec.encodeNormalized([double.infinity]),
        throwsArgumentError,
      );
    });

    test('validates exact dimension byte length', () {
      final bytes = codec.encodeNormalized([1, 0, 0]);

      expect(() => codec.validateBytes(bytes, dimension: 3), returnsNormally);
      expect(
        () => codec.validateBytes(bytes, dimension: 2),
        throwsArgumentError,
      );
      expect(
        () => codec.validateBytes(Uint8List.fromList([1, 2, 3]), dimension: 1),
        throwsArgumentError,
      );
    });
  });
}
