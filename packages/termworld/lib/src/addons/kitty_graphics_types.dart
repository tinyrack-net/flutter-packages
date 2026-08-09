/// Kitty graphics protocol action values.
abstract final class KittyAction {
  /// Transmit image data.
  static const String transmit = 't';

  /// Transmit and display image data.
  static const String transmitDisplay = 'T';

  /// Query protocol support.
  static const String query = 'q';

  /// Place a stored image.
  static const String placement = 'p';

  /// Delete images or placements.
  static const String delete = 'd';
}

/// Kitty graphics protocol pixel formats.
abstract final class KittyFormat {
  /// Packed RGB pixels.
  static const int rgb = 24;

  /// Packed RGBA pixels.
  static const int rgba = 32;

  /// PNG image data.
  static const int png = 100;
}

/// Kitty graphics compression values.
abstract final class KittyCompression {
  /// No compression.
  static const String none = '';

  /// Zlib compression.
  static const String zlib = 'z';
}

/// Kitty graphics control-data keys.
abstract final class KittyKey {
  /// Action key.
  static const String action = 'a';

  /// Format key.
  static const String format = 'f';

  /// Image identifier key.
  static const String id = 'i';

  /// Image-number key.
  static const String imageNumber = 'I';

  /// Source width key.
  static const String width = 's';

  /// Source height key.
  static const String height = 'v';

  /// Source horizontal-offset key.
  static const String xOffset = 'x';

  /// Source vertical-offset key.
  static const String yOffset = 'y';

  /// Source rectangle width key.
  static const String sourceWidth = 'w';

  /// Source rectangle height key.
  static const String sourceHeight = 'h';

  /// In-cell horizontal placement offset key.
  static const String xPlacementOffset = 'X';

  /// In-cell vertical placement offset key.
  static const String yPlacementOffset = 'Y';

  /// Display-column count key.
  static const String columns = 'c';

  /// Display-row count key.
  static const String rows = 'r';

  /// Continuation flag key.
  static const String more = 'm';

  /// Compression key.
  static const String compression = 'o';

  /// Quiet-mode key.
  static const String quiet = 'q';

  /// Cursor-movement key.
  static const String cursorMovement = 'C';

  /// Z-index key.
  static const String zIndex = 'z';

  /// Transmission-medium key.
  static const String transmission = 't';

  /// Delete-selector key.
  static const String deleteSelector = 'd';

  /// Placement identifier key.
  static const String placementId = 'p';
}

/// Pixel constants used by raw Kitty graphics payloads.
abstract final class KittyPixelConstants {
  /// Bytes per RGB pixel.
  static const int bytesPerPixelRgb = 3;

  /// Bytes per RGBA pixel.
  static const int bytesPerPixelRgba = 4;

  /// Fully opaque alpha byte.
  static const int alphaOpaque = 255;
}

/// Parsed Kitty graphics control data.
///
/// Numeric values use [num] because JavaScript's `parseInt` produces `NaN`
/// for malformed values. This preserves that observable upstream result.
final class KittyCommand {
  /// Creates a parsed command value.
  const KittyCommand({
    this.action,
    this.format,
    this.id,
    this.imageNumber,
    this.width,
    this.height,
    this.x,
    this.y,
    this.sourceWidth,
    this.sourceHeight,
    this.xOffset,
    this.yOffset,
    this.columns,
    this.rows,
    this.more,
    this.quiet,
    this.cursorMovement,
    this.zIndex,
    this.transmission,
    this.deleteSelector,
    this.placementId,
    this.compression,
    this.payload,
  });

  /// Requested action.
  final String? action;

  /// Pixel format.
  final num? format;

  /// Image identifier.
  final num? id;

  /// Client image number.
  final num? imageNumber;

  /// Source width in pixels.
  final num? width;

  /// Source height in pixels.
  final num? height;

  /// Source horizontal offset in pixels.
  final num? x;

  /// Source vertical offset in pixels.
  final num? y;

  /// Source rectangle width in pixels.
  final num? sourceWidth;

  /// Source rectangle height in pixels.
  final num? sourceHeight;

  /// Horizontal offset within the first cell.
  final num? xOffset;

  /// Vertical offset within the first cell.
  final num? yOffset;

  /// Display width in terminal columns.
  final num? columns;

  /// Display height in terminal rows.
  final num? rows;

  /// Whether more chunks follow.
  final num? more;

  /// Response suppression level.
  final num? quiet;

  /// Cursor movement policy.
  final num? cursorMovement;

  /// Placement stacking order.
  final num? zIndex;

  /// Transmission medium.
  final String? transmission;

  /// Delete target selector.
  final String? deleteSelector;

  /// Placement identifier.
  final num? placementId;

  /// Payload compression method.
  final String? compression;

  /// Optional inline payload.
  final String? payload;
}

/// Parses Kitty graphics control data exactly like xterm.js.
KittyCommand parseKittyCommand(String data) {
  String? action;
  num? format;
  num? id;
  num? imageNumber;
  num? width;
  num? height;
  num? x;
  num? y;
  num? sourceWidth;
  num? sourceHeight;
  num? xOffset;
  num? yOffset;
  num? columns;
  num? rows;
  num? more;
  num? quiet;
  num? cursorMovement;
  num? zIndex;
  String? transmission;
  String? deleteSelector;
  num? placementId;
  String? compression;
  for (final part in data.split(',')) {
    final separator = part.indexOf('=');
    if (separator == -1) continue;
    final key = part.substring(0, separator);
    final value = part.substring(separator + 1);
    if (key == KittyKey.action) {
      action = value;
      continue;
    }
    if (key == KittyKey.compression) {
      compression = value;
      continue;
    }
    if (key == KittyKey.transmission) {
      transmission = value;
      continue;
    }
    if (key == KittyKey.deleteSelector) {
      deleteSelector = value;
      continue;
    }
    final number = _parseInt(value);
    switch (key) {
      case KittyKey.format:
        format = number;
      case KittyKey.id:
        id = number;
      case KittyKey.imageNumber:
        imageNumber = number;
      case KittyKey.width:
        width = number;
      case KittyKey.height:
        height = number;
      case KittyKey.xOffset:
        x = number;
      case KittyKey.yOffset:
        y = number;
      case KittyKey.sourceWidth:
        sourceWidth = number;
      case KittyKey.sourceHeight:
        sourceHeight = number;
      case KittyKey.xPlacementOffset:
        xOffset = number;
      case KittyKey.yPlacementOffset:
        yOffset = number;
      case KittyKey.columns:
        columns = number;
      case KittyKey.rows:
        rows = number;
      case KittyKey.more:
        more = number;
      case KittyKey.quiet:
        quiet = number;
      case KittyKey.cursorMovement:
        cursorMovement = number;
      case KittyKey.zIndex:
        zIndex = number;
      case KittyKey.placementId:
        placementId = number;
    }
  }
  return KittyCommand(
    action: action,
    format: format,
    id: id,
    imageNumber: imageNumber,
    width: width,
    height: height,
    x: x,
    y: y,
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    xOffset: xOffset,
    yOffset: yOffset,
    columns: columns,
    rows: rows,
    more: more,
    quiet: quiet,
    cursorMovement: cursorMovement,
    zIndex: zIndex,
    transmission: transmission,
    deleteSelector: deleteSelector,
    placementId: placementId,
    compression: compression,
  );
}

num _parseInt(String value) {
  final match = RegExp(r'^\s*([+-]?\d+)').firstMatch(value);
  if (match == null) return double.nan;
  return double.tryParse(match.group(1)!) ?? double.nan;
}
