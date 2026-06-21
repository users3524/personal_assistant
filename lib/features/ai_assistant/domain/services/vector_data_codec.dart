import 'dart:math' as math;
import 'dart:typed_data';

class VectorDataCodec {
  static const encodingVersion = 'float32_le_v1';
  static const bytesPerValue = 4;

  const VectorDataCodec();

  Uint8List encodeNormalized(List<double> values) {
    if (values.isEmpty) {
      throw ArgumentError.value(values.length, 'values', 'Vector is empty.');
    }

    final norm = _l2Norm(values);
    if (norm == 0 || norm.isNaN || norm.isInfinite) {
      throw ArgumentError.value(
        values,
        'values',
        'Vector norm must be finite and non-zero.',
      );
    }

    final bytes = Uint8List(values.length * bytesPerValue);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < values.length; i++) {
      data.setFloat32(i * bytesPerValue, values[i] / norm, Endian.little);
    }
    return bytes;
  }

  List<double> decode(Uint8List bytes, {required int dimension}) {
    validateBytes(bytes, dimension: dimension);
    final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    return List<double>.unmodifiable(
      List.generate(
        dimension,
        (index) => data.getFloat32(index * bytesPerValue, Endian.little),
      ),
    );
  }

  void validateBytes(Uint8List bytes, {required int dimension}) {
    if (dimension <= 0) {
      throw ArgumentError.value(
        dimension,
        'dimension',
        'Vector dimension must be positive.',
      );
    }
    final expectedBytes = byteLengthForDimension(dimension);
    if (bytes.length != expectedBytes) {
      throw ArgumentError.value(
        bytes.length,
        'vectorData',
        'float32_le_v1 requires exactly $expectedBytes bytes for '
            '$dimension dimensions.',
      );
    }
  }

  int byteLengthForDimension(int dimension) {
    if (dimension <= 0) {
      throw ArgumentError.value(
        dimension,
        'dimension',
        'Vector dimension must be positive.',
      );
    }
    return dimension * bytesPerValue;
  }

  double _l2Norm(List<double> values) {
    var sum = 0.0;
    for (final value in values) {
      if (value.isNaN || value.isInfinite) {
        return double.nan;
      }
      sum += value * value;
    }
    return math.sqrt(sum);
  }
}
