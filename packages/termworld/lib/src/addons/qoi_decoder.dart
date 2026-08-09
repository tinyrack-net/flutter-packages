import 'dart:typed_data';

/// Decoded RGBA pixels from a Quite OK Image payload.
final class QoiDecodedImage {
  /// Creates a decoded image.
  const QoiDecodedImage({
    required this.width,
    required this.height,
    required this.pixels,
  });

  /// Pixel width from the QOI header.
  final int width;

  /// Pixel height from the QOI header.
  final int height;

  /// Row-major RGBA8888 pixels.
  final Uint8List pixels;
}

/// Decodes the complete QOI v1 opcode stream without external dependencies.
QoiDecodedImage decodeQoi(Uint8List data) {
  if (data.length < 22 ||
      data[0] != 0x71 ||
      data[1] != 0x6f ||
      data[2] != 0x69 ||
      data[3] != 0x66) {
    throw const FormatException('Invalid QOI header');
  }
  final width = _read32(data, 4);
  final height = _read32(data, 8);
  final channels = data[12];
  if (width <= 0 || height <= 0 || (channels != 3 && channels != 4)) {
    throw const FormatException('Invalid QOI dimensions or channel count');
  }
  final pixelCount = width * height;
  if (pixelCount > 0x3fffffff) {
    throw const FormatException('QOI image is too large');
  }
  final output = Uint8List(pixelCount * 4);
  final index = List<int>.filled(64 * 4, 0);
  var red = 0;
  var green = 0;
  var blue = 0;
  var alpha = 255;
  var input = 14;
  var outputPixel = 0;
  var run = 0;
  while (outputPixel < pixelCount) {
    if (run > 0) {
      run--;
    } else {
      if (input >= data.length - 8) {
        throw const FormatException('Truncated QOI opcode stream');
      }
      final first = data[input++];
      if (first == 0xfe) {
        if (input + 2 >= data.length) {
          throw const FormatException('Truncated QOI RGB opcode');
        }
        red = data[input++];
        green = data[input++];
        blue = data[input++];
      } else if (first == 0xff) {
        if (input + 3 >= data.length) {
          throw const FormatException('Truncated QOI RGBA opcode');
        }
        red = data[input++];
        green = data[input++];
        blue = data[input++];
        alpha = data[input++];
      } else {
        switch (first & 0xc0) {
          case 0x00:
            final offset = (first & 0x3f) * 4;
            red = index[offset];
            green = index[offset + 1];
            blue = index[offset + 2];
            alpha = index[offset + 3];
          case 0x40:
            red = (red + ((first >> 4 & 0x03) - 2)) & 0xff;
            green = (green + ((first >> 2 & 0x03) - 2)) & 0xff;
            blue = (blue + ((first & 0x03) - 2)) & 0xff;
          case 0x80:
            if (input >= data.length) {
              throw const FormatException('Truncated QOI luma opcode');
            }
            final second = data[input++];
            final greenDifference = (first & 0x3f) - 32;
            red = (red + greenDifference + (second >> 4) - 8) & 0xff;
            green = (green + greenDifference) & 0xff;
            blue = (blue + greenDifference + (second & 0x0f) - 8) & 0xff;
          case 0xc0:
            run = first & 0x3f;
        }
      }
      final hash = (red * 3 + green * 5 + blue * 7 + alpha * 11) % 64 * 4;
      index[hash] = red;
      index[hash + 1] = green;
      index[hash + 2] = blue;
      index[hash + 3] = alpha;
    }
    final offset = outputPixel++ * 4;
    output[offset] = red;
    output[offset + 1] = green;
    output[offset + 2] = blue;
    output[offset + 3] = alpha;
  }
  return QoiDecodedImage(width: width, height: height, pixels: output);
}

int _read32(Uint8List data, int offset) =>
    data[offset] << 24 |
    data[offset + 1] << 16 |
    data[offset + 2] << 8 |
    data[offset + 3];
