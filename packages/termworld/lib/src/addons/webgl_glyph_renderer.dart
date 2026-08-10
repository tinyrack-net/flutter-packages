import 'dart:typed_data';

import 'package:termworld/src/addons/webgl_rectangle_renderer.dart';
import 'package:vtworld/vtworld.dart';

/// Number of float attributes uploaded for each instanced glyph.
const int terminalWebglGlyphFloatCount = 11;

/// Two-dimensional glyph metric.
final class TerminalWebglGlyphVector {
  /// Creates a vector.
  const TerminalWebglGlyphVector(this.x, this.y);

  /// Horizontal component.
  final double x;

  /// Vertical component.
  final double y;
}

/// One rasterized glyph entry in the terminal texture atlas.
final class TerminalWebglRasterizedGlyph {
  /// Creates a rasterized glyph snapshot.
  const TerminalWebglRasterizedGlyph({
    required this.offset,
    required this.size,
    required this.texturePage,
    required this.texturePositionClipSpace,
    required this.sizeClipSpace,
  });

  /// Device-pixel offset from the character origin.
  final TerminalWebglGlyphVector offset;

  /// Device-pixel raster size.
  final TerminalWebglGlyphVector size;

  /// Texture atlas page index.
  final int texturePage;

  /// Normalized top-left atlas coordinate.
  final TerminalWebglGlyphVector texturePositionClipSpace;

  /// Normalized atlas extent.
  final TerminalWebglGlyphVector sizeClipSpace;
}

/// Texture atlas page dimensions and monotonic content version.
final class TerminalWebglGlyphAtlasPage {
  /// Creates an atlas page snapshot.
  const TerminalWebglGlyphAtlasPage({
    required this.width,
    required this.height,
    required this.version,
  });

  /// Texture width in device pixels.
  final double width;

  /// Texture height in device pixels.
  final double height;

  /// Globally monotonic page content version.
  final int version;
}

/// Atlas operations needed by xterm's glyph renderer.
abstract interface class TerminalWebglGlyphAtlas {
  /// Current atlas page layout generation.
  int get pageLayoutVersion;

  /// Current atlas pages.
  List<TerminalWebglGlyphAtlasPage> get pages;

  /// Returns the raster for a single code point.
  TerminalWebglRasterizedGlyph getGlyph(
    int code,
    int background,
    int foreground,
    int extended,
  );

  /// Returns the raster for a combined-character string.
  TerminalWebglRasterizedGlyph getCombinedGlyph(
    String characters,
    int background,
    int foreground,
    int extended,
  );
}

/// Character and canvas metrics needed by the glyph renderer.
final class TerminalWebglGlyphDimensions {
  /// Creates a dimensions snapshot.
  const TerminalWebglGlyphDimensions({
    required this.device,
    required this.characterWidth,
    required this.characterLeft,
    required this.characterTop,
  });

  /// Cell and canvas dimensions.
  final TerminalWebglDeviceDimensions device;

  /// Character width in device pixels.
  final double characterWidth;

  /// Character left inset in device pixels.
  final double characterLeft;

  /// Character top inset in device pixels.
  final double characterTop;
}

/// CPU-side glyph instance buffers, including xterm's double buffering.
final class TerminalWebglGlyphRendererModel {
  /// Creates and clears a glyph renderer model.
  TerminalWebglGlyphRendererModel({
    required this.columns,
    required this.rows,
    required this.dimensions,
    this.rescaleOverlappingGlyphs = false,
  }) {
    clear();
  }

  /// Terminal columns.
  int columns;

  /// Terminal rows.
  int rows;

  /// Current renderer dimensions.
  TerminalWebglGlyphDimensions dimensions;

  /// Whether oversized single-cell glyphs are horizontally rescaled.
  bool rescaleOverlappingGlyphs;

  TerminalWebglGlyphAtlas? _atlas;
  var _lastSeenPageLayoutVersion = -1;
  var _activeBuffer = 0;
  Float32List _attributes = Float32List(0);
  final List<Float32List> _attributeBuffers = <Float32List>[
    Float32List(0),
    Float32List(0),
  ];
  var _count = 0;

  /// Mutable canonical cell attributes for the next frame.
  Float32List get attributes => _attributes;

  /// Total float count, including static cell positions.
  int get count => _count;

  /// Current double-buffer index.
  int get activeBuffer => _activeBuffer;

  /// Sets an atlas and forces the next frame to rebuild the complete model.
  void setAtlas(TerminalWebglGlyphAtlas atlas) {
    _atlas = atlas;
    _lastSeenPageLayoutVersion = -1;
  }

  /// Whether atlas replacement or page merging requires a full model rebuild.
  bool beginFrame() {
    final atlas = _atlas;
    if (atlas == null) return true;
    if (atlas.pageLayoutVersion != _lastSeenPageLayoutVersion) {
      _lastSeenPageLayoutVersion = atlas.pageLayoutVersion;
      return true;
    }
    return false;
  }

  /// Clears dynamic glyph data and initializes normalized cell positions.
  void clear() {
    final newCount = columns * rows * terminalWebglGlyphFloatCount;
    if (_count != newCount) {
      _attributes = Float32List(newCount);
      for (var index = 0; index < _attributeBuffers.length; index++) {
        _attributeBuffers[index] = Float32List(newCount);
      }
    } else {
      _attributes.fillRange(0, _attributes.length, 0);
      for (final buffer in _attributeBuffers) {
        buffer.fillRange(0, buffer.length, 0);
      }
    }
    _count = newCount;
    var offset = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        _attributes[offset + 9] = x / columns;
        _attributes[offset + 10] = y / rows;
        offset += terminalWebglGlyphFloatCount;
      }
    }
  }

  /// Resets cell positions and dynamic data after a renderer resize.
  void handleResize(TerminalWebglGlyphDimensions value) {
    dimensions = value;
    clear();
  }

  /// Updates one glyph instance in the canonical attributes buffer.
  void updateCell({
    required int x,
    required int y,
    required int? code,
    required int background,
    required int foreground,
    required int extended,
    required String characters,
    required int width,
    required int lastBackground,
  }) {
    final offset = (y * columns + x) * terminalWebglGlyphFloatCount;
    if (code == null || code == 0) {
      _attributes.fillRange(offset, offset + 9, 0);
      return;
    }
    final atlas = _atlas;
    if (atlas == null) return;
    final glyph = characters.length > 1
        ? atlas.getCombinedGlyph(
            characters,
            background,
            foreground,
            extended,
          )
        : atlas.getGlyph(code, background, foreground, extended);
    final cell = dimensions.device;
    final leftCellPadding = ((cell.cellWidth - dimensions.characterWidth) / 2)
        .floor();
    if (background != lastBackground && glyph.offset.x > leftCellPadding) {
      final clippedPixels = glyph.offset.x - leftCellPadding;
      _attributes[offset] =
          -(glyph.offset.x - clippedPixels) + dimensions.characterLeft;
      _attributes[offset + 1] = -glyph.offset.y + dimensions.characterTop;
      _attributes[offset + 2] =
          (glyph.size.x - clippedPixels) / cell.canvasWidth;
      _attributes[offset + 3] = glyph.size.y / cell.canvasHeight;
      _attributes[offset + 4] = glyph.texturePage.toDouble();
      _attributes[offset + 5] =
          glyph.texturePositionClipSpace.x +
          clippedPixels / atlas.pages[glyph.texturePage].width;
      _attributes[offset + 6] = glyph.texturePositionClipSpace.y;
      _attributes[offset + 7] =
          glyph.sizeClipSpace.x -
          clippedPixels / atlas.pages[glyph.texturePage].width;
      _attributes[offset + 8] = glyph.sizeClipSpace.y;
    } else {
      _attributes[offset] = -glyph.offset.x + dimensions.characterLeft;
      _attributes[offset + 1] = -glyph.offset.y + dimensions.characterTop;
      _attributes[offset + 2] = glyph.size.x / cell.canvasWidth;
      _attributes[offset + 3] = glyph.size.y / cell.canvasHeight;
      _attributes[offset + 4] = glyph.texturePage.toDouble();
      _attributes[offset + 5] = glyph.texturePositionClipSpace.x;
      _attributes[offset + 6] = glyph.texturePositionClipSpace.y;
      _attributes[offset + 7] = glyph.sizeClipSpace.x;
      _attributes[offset + 8] = glyph.sizeClipSpace.y;
    }
    if (rescaleOverlappingGlyphs &&
        allowGlyphRescaling(code, width, glyph.size.x, cell.cellWidth)) {
      _attributes[offset + 2] = (cell.cellWidth - 1) / cell.canvasWidth;
    }
  }

  /// Alternates buffers and packs non-whitespace line prefixes for upload.
  Float32List buildUploadBuffer(Uint32List lineLengths) {
    _activeBuffer = (_activeBuffer + 1) % 2;
    final active = _attributeBuffers[_activeBuffer];
    var bufferLength = 0;
    for (var y = 0; y < lineLengths.length; y++) {
      final sourceStart = y * columns * terminalWebglGlyphFloatCount;
      final sourceEnd =
          sourceStart + lineLengths[y] * terminalWebglGlyphFloatCount;
      active.setRange(
        bufferLength,
        bufferLength + sourceEnd - sourceStart,
        _attributes,
        sourceStart,
      );
      bufferLength += sourceEnd - sourceStart;
    }
    return Float32List.sublistView(active, 0, bufferLength);
  }
}
