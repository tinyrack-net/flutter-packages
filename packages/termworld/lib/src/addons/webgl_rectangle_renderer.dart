import 'dart:typed_data';

import 'package:termworld/src/addons/webgl_cell_color_resolver.dart';
import 'package:termworld/src/addons/webgl_utils.dart';

/// Number of float attributes uploaded for each instanced rectangle.
const int terminalWebglRectangleFloatCount = 8;

/// Device-pixel dimensions used by the rectangle renderer.
final class TerminalWebglDeviceDimensions {
  /// Creates a dimensions snapshot.
  const TerminalWebglDeviceDimensions({
    required this.cellWidth,
    required this.cellHeight,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  /// Cell width in device pixels.
  final double cellWidth;

  /// Cell height in device pixels.
  final double cellHeight;

  /// Canvas width in device pixels.
  final double canvasWidth;

  /// Canvas height in device pixels.
  final double canvasHeight;
}

/// Mutable instanced rectangle attribute batch.
final class TerminalWebglRectangleBatch {
  /// Creates an empty batch with xterm's initial 20-rectangle capacity.
  TerminalWebglRectangleBatch()
    : attributes = Float32List(20 * terminalWebglRectangleFloatCount);

  /// Normalized position, size and RGBA attributes.
  Float32List attributes;

  /// Number of live rectangle instances.
  int count = 0;
}

/// CPU side of xterm's WebGL rectangle renderer.
final class TerminalWebglRectangleRendererModel {
  /// Creates the renderer model and its viewport-clear rectangle.
  factory TerminalWebglRectangleRendererModel({
    required int columns,
    required int rows,
    required TerminalWebglDeviceDimensions dimensions,
    required TerminalWebglCellColorSet colors,
    required int cursorRgba,
  }) => TerminalWebglRectangleRendererModel._(
    columns,
    rows,
    dimensions,
    colors,
    cursorRgba,
  );

  TerminalWebglRectangleRendererModel._(
    this.columns,
    this.rows,
    this.dimensions,
    this._colors,
    this._cursorRgba,
  ) {
    _updateViewportRectangle();
  }

  /// Terminal column count.
  int columns;

  /// Terminal row count.
  int rows;

  /// Device dimensions used by subsequent geometry updates.
  TerminalWebglDeviceDimensions dimensions;
  TerminalWebglCellColorSet _colors;
  int _cursorRgba;

  /// Viewport-clear and non-default cell background rectangles.
  final TerminalWebglRectangleBatch backgrounds = TerminalWebglRectangleBatch();

  /// Non-block cursor rectangles.
  final TerminalWebglRectangleBatch cursor = TerminalWebglRectangleBatch();

  /// Replaces theme colors and refreshes the viewport-clear rectangle.
  void setColors(TerminalWebglCellColorSet colors, int cursorRgba) {
    _colors = colors;
    _cursorRgba = cursorRgba;
    _updateViewportRectangle();
  }

  /// Refreshes size-dependent viewport geometry.
  void handleResize() => _updateViewportRectangle();

  /// Coalesces adjacent cells with equal effective backgrounds.
  void updateBackgrounds(TerminalWebglRenderModel model) {
    var rectangleCount = 1;
    for (var y = 0; y < rows; y++) {
      var currentStartX = -1;
      var currentBackground = 0;
      var currentForeground = 0;
      var currentInverse = false;
      for (var x = 0; x < columns; x++) {
        final modelIndex = (y * columns + x) * terminalWebglIndicesPerCell;
        final background =
            model.cells[modelIndex + terminalWebglBackgroundOffset];
        final foreground =
            model.cells[modelIndex + terminalWebglForegroundOffset];
        final inverse = foreground & TerminalWebglAttributes.inverse != 0;
        if (background != currentBackground ||
            foreground != currentForeground && (currentInverse || inverse)) {
          if (currentBackground != 0 ||
              currentInverse && currentForeground != 0) {
            _updateRectangle(
              rectangleCount++ * terminalWebglRectangleFloatCount,
              currentForeground,
              currentBackground,
              currentStartX,
              x,
              y,
            );
          }
          currentStartX = x;
          currentBackground = background;
          currentForeground = foreground;
          currentInverse = inverse;
        }
      }
      if (currentBackground != 0 || currentInverse && currentForeground != 0) {
        _updateRectangle(
          rectangleCount++ * terminalWebglRectangleFloatCount,
          currentForeground,
          currentBackground,
          currentStartX,
          columns,
          y,
        );
      }
    }
    backgrounds.count = rectangleCount;
  }

  /// Builds bar, underline or outline cursor rectangle instances.
  void updateCursor(TerminalWebglRenderModel model) {
    final current = model.cursor;
    if (current == null || current.style == 'block') {
      cursor.count = 0;
      return;
    }
    final color = _colorToFloat32(_cursorRgba);
    var rectangleCount = 0;
    if (current.style == 'bar' || current.style == 'outline') {
      _addRectangleFloat(
        cursor.attributes,
        rectangleCount++ * terminalWebglRectangleFloatCount,
        current.x * dimensions.cellWidth,
        current.y * dimensions.cellHeight,
        current.style == 'bar'
            ? current.devicePixelRatio * current.cursorWidth
            : current.devicePixelRatio,
        dimensions.cellHeight,
        color,
      );
    }
    if (current.style == 'underline' || current.style == 'outline') {
      _addRectangleFloat(
        cursor.attributes,
        rectangleCount++ * terminalWebglRectangleFloatCount,
        current.x * dimensions.cellWidth,
        (current.y + 1) * dimensions.cellHeight - current.devicePixelRatio,
        current.width * dimensions.cellWidth,
        current.devicePixelRatio,
        color,
      );
    }
    if (current.style == 'outline') {
      _addRectangleFloat(
        cursor.attributes,
        rectangleCount++ * terminalWebglRectangleFloatCount,
        current.x * dimensions.cellWidth,
        current.y * dimensions.cellHeight,
        current.width * dimensions.cellWidth,
        current.devicePixelRatio,
        color,
      );
      _addRectangleFloat(
        cursor.attributes,
        rectangleCount++ * terminalWebglRectangleFloatCount,
        (current.x + current.width) * dimensions.cellWidth -
            current.devicePixelRatio,
        current.y * dimensions.cellHeight,
        current.devicePixelRatio,
        dimensions.cellHeight,
        color,
      );
    }
    cursor.count = rectangleCount;
  }

  void _updateViewportRectangle() {
    _addRectangleFloat(
      backgrounds.attributes,
      0,
      0,
      0,
      columns * dimensions.cellWidth,
      rows * dimensions.cellHeight,
      _colorToFloat32(_colors.backgroundRgba),
    );
  }

  void _updateRectangle(
    int offset,
    int foreground,
    int background,
    int startX,
    int endX,
    int y,
  ) {
    final rgba = foreground & TerminalWebglAttributes.inverse != 0
        ? _resolveForeground(foreground)
        : _resolveBackground(background);
    if (backgrounds.attributes.length <
        offset + terminalWebglRectangleFloatCount) {
      backgrounds.attributes = expandTerminalFloat32List(
        backgrounds.attributes,
        (rows * columns + 1) * terminalWebglRectangleFloatCount,
      );
    }
    _addRectangle(
      backgrounds.attributes,
      offset,
      startX * dimensions.cellWidth,
      y * dimensions.cellHeight,
      (endX - startX) * dimensions.cellWidth,
      dimensions.cellHeight,
      (rgba >> 24 & 0xff) / 255,
      (rgba >> 16 & 0xff) / 255,
      (rgba >> 8 & 0xff) / 255,
      1,
    );
  }

  int _resolveForeground(int packed) {
    return switch (packed & TerminalWebglAttributes.colorModeMask) {
      TerminalWebglAttributes.colorModePalette16 ||
      TerminalWebglAttributes.colorModePalette256 =>
        _colors.ansi[packed & TerminalWebglAttributes.paletteColorMask],
      TerminalWebglAttributes.colorModeRgb =>
        (packed & TerminalWebglAttributes.rgbMask) << 8,
      _ => _colors.foregroundRgba,
    };
  }

  int _resolveBackground(int packed) {
    return switch (packed & TerminalWebglAttributes.colorModeMask) {
      TerminalWebglAttributes.colorModePalette16 ||
      TerminalWebglAttributes.colorModePalette256 =>
        _colors.ansi[packed & TerminalWebglAttributes.paletteColorMask],
      TerminalWebglAttributes.colorModeRgb =>
        (packed & TerminalWebglAttributes.rgbMask) << 8,
      _ => _colors.backgroundRgba,
    };
  }

  void _addRectangleFloat(
    Float32List array,
    int offset,
    double x,
    double y,
    double width,
    double height,
    Float32List color,
  ) {
    _addRectangle(
      array,
      offset,
      x,
      y,
      width,
      height,
      color[0],
      color[1],
      color[2],
      color[3],
    );
  }

  void _addRectangle(
    Float32List array,
    int offset,
    double x,
    double y,
    double width,
    double height,
    double red,
    double green,
    double blue,
    double alpha,
  ) {
    array[offset] = x / dimensions.canvasWidth;
    array[offset + 1] = y / dimensions.canvasHeight;
    array[offset + 2] = width / dimensions.canvasWidth;
    array[offset + 3] = height / dimensions.canvasHeight;
    array[offset + 4] = red;
    array[offset + 5] = green;
    array[offset + 6] = blue;
    array[offset + 7] = alpha;
  }
}

Float32List _colorToFloat32(int rgba) => Float32List.fromList(<double>[
  (rgba >> 24 & 0xff) / 255,
  (rgba >> 16 & 0xff) / 255,
  (rgba >> 8 & 0xff) / 255,
  (rgba & 0xff) / 255,
]);
