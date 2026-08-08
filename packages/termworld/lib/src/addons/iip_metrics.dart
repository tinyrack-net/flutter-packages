import 'dart:typed_data';

/// MIME classification returned by [iipImageType].
enum IipImageType {
  /// PNG image.
  png('image/png'),

  /// JPEG image.
  jpeg('image/jpeg'),

  /// GIF image.
  gif('image/gif'),

  /// Quite OK Image Format image.
  qoi('image/qoi'),

  /// Data with an unsupported or invalid header.
  unsupported('unsupported'),

  /// No image type.
  empty('');

  const IipImageType(this.mime);

  /// xterm.js MIME string.
  final String mime;
}

/// Dimensions and MIME type inferred from an image header.
final class IipImageMetrics {
  /// Creates image metrics.
  const IipImageMetrics({
    required this.type,
    required this.width,
    required this.height,
  });

  /// Detected format.
  final IipImageType type;

  /// MIME string used by xterm.js.
  String get mime => type.mime;

  /// Pixel width.
  final int width;

  /// Pixel height.
  final int height;
}

/// Shared result for unsupported image data.
const IipImageMetrics unsupportedIipImageType = IipImageMetrics(
  type: IipImageType.unsupported,
  width: 0,
  height: 0,
);

/// Reads PNG, JPEG, GIF, or QOI dimensions from [data].
IipImageMetrics iipImageType(Uint8List data) {
  if (data.length < 24) return unsupportedIipImageType;
  if (data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4e &&
      data[3] == 0x47 &&
      data[4] == 0x0d &&
      data[5] == 0x0a &&
      data[6] == 0x1a &&
      data[7] == 0x0a &&
      data[12] == 0x49 &&
      data[13] == 0x48 &&
      data[14] == 0x44 &&
      data[15] == 0x52) {
    return IipImageMetrics(
      type: IipImageType.png,
      width: _bigEndian32(data, 16),
      height: _bigEndian32(data, 20),
    );
  }
  if (data[0] == 0xff && data[1] == 0xd8 && data[2] == 0xff) {
    final size = _jpegSize(data);
    return IipImageMetrics(
      type: IipImageType.jpeg,
      width: size.$1,
      height: size.$2,
    );
  }
  if (data[0] == 0x47 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x38 &&
      (data[4] == 0x37 || data[4] == 0x39) &&
      data[5] == 0x61) {
    return IipImageMetrics(
      type: IipImageType.gif,
      width: data[7] << 8 | data[6],
      height: data[9] << 8 | data[8],
    );
  }
  if (data[0] == 0x71 &&
      data[1] == 0x6f &&
      data[2] == 0x69 &&
      data[3] == 0x66) {
    return IipImageMetrics(
      type: IipImageType.qoi,
      width: _bigEndian32(data, 4),
      height: _bigEndian32(data, 8),
    );
  }
  return unsupportedIipImageType;
}

(int, int) _jpegSize(Uint8List data) {
  final length = data.length;
  var index = 4;
  var blockLength = data[index] << 8 | data[index + 1];
  while (true) {
    index += blockLength;
    if (index >= length || data[index] != 0xff) return (0, 0);
    if (data[index + 1] == 0xc0 || data[index + 1] == 0xc2) {
      if (index + 8 < length) {
        return (
          data[index + 7] << 8 | data[index + 8],
          data[index + 5] << 8 | data[index + 6],
        );
      }
      return (0, 0);
    }
    index += 2;
    blockLength = data[index] << 8 | data[index + 1];
  }
}

int _bigEndian32(Uint8List data, int offset) {
  final value =
      data[offset] << 24 |
      data[offset + 1] << 16 |
      data[offset + 2] << 8 |
      data[offset + 3];
  return value >= 0x80000000 ? value - 0x100000000 : value;
}
