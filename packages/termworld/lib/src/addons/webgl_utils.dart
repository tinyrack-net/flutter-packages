import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:termworld/src/core/selection_render_model.dart';

/// Number of packed model words used for each terminal cell.
const int terminalWebglIndicesPerCell = 4;

/// Offset of the packed background word within a cell.
const int terminalWebglBackgroundOffset = 1;

/// Offset of the packed foreground word within a cell.
const int terminalWebglForegroundOffset = 2;

/// Offset of the packed extended-attributes word within a cell.
const int terminalWebglExtendedOffset = 3;

/// Flag marking a model entry as a combined-character string reference.
const int terminalWebglCombinedCharacterMask = 0x80000000;

/// Whether a custom vector shape is filled or stroked.
enum TerminalCustomGlyphVectorType {
  /// Fill the vector path.
  fill,

  /// Stroke the vector path.
  stroke,
}

/// Storage/drawing representation used by a custom terminal glyph.
enum TerminalCustomGlyphDefinitionType {
  /// Solid cell octants.
  solidOctantBlockVector,

  /// Repeated bitmap pattern.
  blockPattern,

  /// Parameterized path factory.
  pathFunction,

  /// Literal path.
  path,

  /// Literal path subtracted from the cell.
  pathNegative,

  /// Fill or stroke vector shape.
  vectorShape,

  /// Braille dot mask.
  braille,
}

/// Coordinate system used to scale custom glyph geometry.
enum TerminalCustomGlyphScaleType {
  /// Scale to the full cell including letter spacing and line height.
  cell,

  /// Scale to the character area only.
  character,
}

/// One rectangular octant fragment of a custom block glyph.
@immutable
final class TerminalCustomGlyphSolidOctant {
  /// Creates an octant fragment in normalized eighth-cell units.
  const TerminalCustomGlyphSolidOctant({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Horizontal origin.
  final int x;

  /// Vertical origin.
  final int y;

  /// Horizontal extent.
  final int width;

  /// Vertical extent.
  final int height;
}

/// A custom glyph vector path and its paint operation.
@immutable
final class TerminalCustomGlyphVectorShape {
  /// Creates a custom vector shape.
  const TerminalCustomGlyphVectorShape({
    required this.path,
    required this.type,
    this.leftPadding,
    this.rightPadding,
  });

  /// SVG-compatible path data normalized to the cell.
  final String path;

  /// Fill or stroke operation.
  final TerminalCustomGlyphVectorType type;

  /// Optional normalized left padding.
  final double? leftPadding;

  /// Optional normalized right padding.
  final double? rightPadding;
}

/// One normalized custom glyph drawing part.
@immutable
final class TerminalCustomGlyphPart {
  /// Creates a custom glyph part.
  const TerminalCustomGlyphPart({
    required this.type,
    required this.data,
    this.clipPath,
    this.strokeWidth = 1,
    this.scaleType = TerminalCustomGlyphScaleType.cell,
  });

  /// Drawing representation.
  final TerminalCustomGlyphDefinitionType type;

  /// Representation-specific immutable data.
  final Object data;

  /// Optional normalized clipping path.
  final String? clipPath;

  /// Stroke width used by path-based definitions.
  final double strokeWidth;

  /// Geometry scaling coordinate system.
  final TerminalCustomGlyphScaleType scaleType;
}

/// Cursor information captured for a WebGL render frame.
final class TerminalWebglCursorModel {
  /// Creates a cursor snapshot.
  const TerminalWebglCursorModel({
    required this.x,
    required this.y,
    required this.width,
    required this.style,
    required this.cursorWidth,
    required this.devicePixelRatio,
  });

  /// Zero-based cursor column.
  final int x;

  /// Zero-based cursor row.
  final int y;

  /// Cursor width in cells.
  final int width;

  /// Cursor style value supplied by terminal options.
  final Object style;

  /// Bar-cursor width in logical pixels.
  final int cursorWidth;

  /// Device pixel ratio used for this frame.
  final double devicePixelRatio;
}

/// Packed WebGL cell, line-length, selection and cursor render state.
final class TerminalWebglRenderModel {
  /// Creates an empty render model.
  TerminalWebglRenderModel();

  /// Four packed words per terminal cell.
  Uint32List cells = Uint32List(0);

  /// Rendered content length for every viewport row.
  Uint32List lineLengths = Uint32List(0);

  /// Selection geometry shared with the renderer.
  final SelectionRenderModel selection = createSelectionRenderModel();

  /// Current cursor snapshot, or null when it is not rendered.
  TerminalWebglCursorModel? cursor;

  /// Resizes storage when the cell count changes.
  void resize(int columns, int rows) {
    final indexCount = columns * rows * terminalWebglIndicesPerCell;
    if (indexCount == cells.length) return;
    cells = Uint32List(indexCount);
    lineLengths = Uint32List(rows);
  }

  /// Zeros all packed cell and row-length data.
  void clear() {
    cells.fillRange(0, cells.length, 0);
    lineLengths.fillRange(0, lineLengths.length, 0);
  }
}

/// One cell rectangle used to draw or clear a WebGL link underline.
@immutable
final class TerminalWebglCellRectangle {
  /// Creates a cell rectangle.
  const TerminalWebglCellRectangle({
    required this.x,
    required this.y,
    required this.width,
    this.height = 1,
  });

  /// Starting column.
  final int x;

  /// Starting row.
  final int y;

  /// Width in cells.
  final int width;

  /// Height in cells.
  final int height;

  @override
  bool operator ==(Object other) =>
      other is TerminalWebglCellRectangle &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// Computes underline spans for xterm's inclusive-row/exclusive-column link.
List<TerminalWebglCellRectangle> terminalWebglLinkUnderlineRectangles({
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required int columns,
}) {
  if (y1 == y2) {
    return <TerminalWebglCellRectangle>[
      TerminalWebglCellRectangle(x: x1, y: y1, width: x2 - x1),
    ];
  }
  return <TerminalWebglCellRectangle>[
    TerminalWebglCellRectangle(x: x1, y: y1, width: columns - x1),
    for (var row = y1 + 1; row < y2; row++)
      TerminalWebglCellRectangle(x: 0, y: row, width: columns),
    TerminalWebglCellRectangle(x: 0, y: y2, width: x2),
  ];
}

/// Computes the coalesced rectangles cleared when a link underline hides.
List<TerminalWebglCellRectangle> terminalWebglLinkClearRectangles({
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required int columns,
}) {
  final middleRows = y2 - y1 - 1;
  return <TerminalWebglCellRectangle>[
    TerminalWebglCellRectangle(x: x1, y: y1, width: columns - x1),
    if (middleRows > 0)
      TerminalWebglCellRectangle(
        x: 0,
        y: y1 + 1,
        width: columns,
        height: middleRows,
      ),
    TerminalWebglCellRectangle(x: 0, y: y2, width: x2),
  ];
}

/// Matrix translating normalized top-left coordinates into WebGL clip space.
final Float32List terminalWebglProjectionMatrix = Float32List.fromList(
  <double>[
    2,
    0,
    0,
    0,
    0,
    -2,
    0,
    0,
    0,
    0,
    1,
    0,
    -1,
    1,
    0,
    1,
  ],
);

/// Doubles a WebGL float buffer without exceeding [maximumLength].
Float32List expandTerminalFloat32List(
  Float32List source,
  int maximumLength,
) {
  final newLength = (source.length * 2).clamp(0, maximumLength);
  final copyLength = source.length < newLength ? source.length : newLength;
  return Float32List(newLength)..setRange(0, copyLength, source);
}

/// xterm's typed-array slice fallback, preserving the concrete list type.
T sliceTerminalTypedArray<T extends List<num>>(
  T array, {
  int start = 0,
  int? end,
}) {
  var effectiveStart = start;
  var effectiveEnd = end ?? array.length;
  if (effectiveStart < 0) {
    effectiveStart = (array.length + effectiveStart) % array.length;
  }
  if (effectiveEnd >= array.length) {
    effectiveEnd = array.length;
  } else {
    effectiveEnd = (array.length + effectiveEnd) % array.length;
  }
  if (effectiveStart > effectiveEnd) effectiveStart = effectiveEnd;

  final result = _typedListLike(array, effectiveEnd - effectiveStart);
  for (var index = 0; index < result.length; index++) {
    result[index] = array[index + effectiveStart];
  }
  return result as T;
}

List<num> _typedListLike(List<num> source, int length) => switch (source) {
  Uint8ClampedList() => Uint8ClampedList(length),
  Uint8List() => Uint8List(length),
  Uint16List() => Uint16List(length),
  Uint32List() => Uint32List(length),
  Int8List() => Int8List(length),
  Int16List() => Int16List(length),
  Int32List() => Int32List(length),
  Float32List() => Float32List(length),
  Float64List() => Float64List(length),
  _ => throw ArgumentError.value(source, 'source', 'must be a typed list'),
};

/// Inputs that determine WebGL texture-atlas compatibility.
final class TerminalCharAtlasConfig {
  /// Creates a texture-atlas configuration snapshot.
  const TerminalCharAtlasConfig({
    required this.ansi,
    this.customGlyphs = true,
    this.devicePixelRatio = 1,
    this.deviceMaxTextureSize = 4096,
    this.letterSpacing = 0,
    this.lineHeight = 1,
    this.fontSize = 15,
    this.fontFamily = 'monospace',
    this.fontWeight = 'normal',
    this.fontWeightBold = 'bold',
    this.deviceCellWidth = 10,
    this.deviceCellHeight = 20,
    this.deviceCharWidth = 8,
    this.deviceCharHeight = 16,
    this.allowTransparency = false,
    this.drawBoldTextInBrightColors = true,
    this.minimumContrastRatio = 1,
    this.foreground = 0xffffffff,
    this.background = 0xffffffff,
  });

  /// Whether custom terminal glyph rasterization is enabled.
  final bool customGlyphs;

  /// Device pixels per logical pixel.
  final double devicePixelRatio;

  /// Maximum texture dimension supported by WebGL.
  final int deviceMaxTextureSize;

  /// Extra spacing between rendered cells.
  final double letterSpacing;

  /// Cell line-height multiplier.
  final double lineHeight;

  /// Font size in logical pixels.
  final double fontSize;

  /// CSS font-family value.
  final String fontFamily;

  /// Normal font weight.
  final Object fontWeight;

  /// Bold font weight.
  final Object fontWeightBold;

  /// Cell width in device pixels.
  final double deviceCellWidth;

  /// Cell height in device pixels.
  final double deviceCellHeight;

  /// Character width in device pixels.
  final double deviceCharWidth;

  /// Character height in device pixels.
  final double deviceCharHeight;

  /// Whether translucent cell backgrounds are retained.
  final bool allowTransparency;

  /// Whether bold cells use bright palette colors.
  final bool drawBoldTextInBrightColors;

  /// Minimum foreground/background contrast ratio.
  final double minimumContrastRatio;

  /// Packed foreground color.
  final int foreground;

  /// Packed background color.
  final int background;

  /// Packed ANSI palette colors.
  final List<int> ansi;
}

/// Disposable atlas contract stored in [TerminalCharAtlasCache].
abstract interface class TerminalDisposableCharAtlas {
  /// Whether the atlas has released its resources.
  bool get isDisposed;

  /// Releases atlas resources.
  void dispose();
}

final class _TerminalCharAtlasCacheEntry<
  T extends TerminalDisposableCharAtlas
> {
  _TerminalCharAtlasCacheEntry(this.atlas, this.config, this.owners);

  final T atlas;
  final TerminalCharAtlasConfig config;
  final List<Object> owners;
}

/// Shares compatible atlases between terminal owners using identity semantics.
final class TerminalCharAtlasCache<T extends TerminalDisposableCharAtlas> {
  final List<_TerminalCharAtlasCacheEntry<T>> _entries =
      <_TerminalCharAtlasCacheEntry<T>>[];

  /// Number of distinct atlas configurations currently retained.
  int get length => _entries.length;

  /// Reuses an owner's atlas, shares a compatible atlas, or creates one.
  T acquire(
    Object owner,
    TerminalCharAtlasConfig config,
    T Function() create,
  ) {
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      final ownerIndex = entry.owners.indexWhere(
        (candidate) => identical(candidate, owner),
      );
      if (ownerIndex < 0) continue;
      if (terminalCharAtlasConfigEquals(entry.config, config)) {
        return entry.atlas;
      }
      if (entry.owners.length == 1) {
        entry.atlas.dispose();
        _entries.removeAt(index);
      } else {
        entry.owners.removeAt(ownerIndex);
      }
      break;
    }
    for (final entry in _entries) {
      if (!terminalCharAtlasConfigEquals(entry.config, config)) continue;
      entry.owners.add(owner);
      return entry.atlas;
    }
    final atlas = create();
    _entries.add(
      _TerminalCharAtlasCacheEntry<T>(atlas, config, <Object>[owner]),
    );
    return atlas;
  }

  /// Removes the first atlas reference owned by [owner].
  void removeOwner(Object owner) {
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      final ownerIndex = entry.owners.indexWhere(
        (candidate) => identical(candidate, owner),
      );
      if (ownerIndex < 0) continue;
      if (entry.owners.length == 1) {
        entry.atlas.dispose();
        _entries.removeAt(index);
      } else {
        entry.owners.removeAt(ownerIndex);
      }
      break;
    }
  }
}

/// Whether two snapshots can share the same WebGL character atlas.
bool terminalCharAtlasConfigEquals(
  TerminalCharAtlasConfig left,
  TerminalCharAtlasConfig right,
) {
  if (left.ansi.length != right.ansi.length) return false;
  for (var index = 0; index < left.ansi.length; index++) {
    if (left.ansi[index] != right.ansi[index]) return false;
  }
  return left.devicePixelRatio == right.devicePixelRatio &&
      left.deviceMaxTextureSize == right.deviceMaxTextureSize &&
      left.customGlyphs == right.customGlyphs &&
      left.lineHeight == right.lineHeight &&
      left.letterSpacing == right.letterSpacing &&
      left.fontFamily == right.fontFamily &&
      left.fontSize == right.fontSize &&
      left.fontWeight == right.fontWeight &&
      left.fontWeightBold == right.fontWeightBold &&
      left.allowTransparency == right.allowTransparency &&
      left.deviceCellWidth == right.deviceCellWidth &&
      left.deviceCellHeight == right.deviceCellHeight &&
      left.deviceCharWidth == right.deviceCharWidth &&
      left.deviceCharHeight == right.deviceCharHeight &&
      left.drawBoldTextInBrightColors == right.drawBoldTextInBrightColors &&
      left.minimumContrastRatio == right.minimumContrastRatio &&
      left.foreground == right.foreground &&
      left.background == right.background;
}
