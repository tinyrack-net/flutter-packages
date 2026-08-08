/// Terminal dimension fitting addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';

/// Proposed terminal row and column count.
final class TerminalDimensions {
  /// xterm-compatible `TerminalDimensions` API.
  const TerminalDimensions({required this.rows, required this.cols});

  /// Rows that fit the renderer.
  final int rows;

  /// Columns that fit the renderer.
  final int cols;
}

/// Fits the terminal buffer to its latest measured Flutter render surface.
final class FitAddon extends ManagedTerminalAddon {
  @override
  void onActivate(Terminal terminal) {}

  /// Returns the dimensions that fit, or null before the view is measured.
  TerminalDimensions? proposeDimensions() {
    final render = terminal.dimensions;
    if (render == null || render.cellWidth <= 0 || render.cellHeight <= 0) {
      return null;
    }
    return TerminalDimensions(
      rows: (render.height / render.cellHeight).floor().clamp(1, 0x7fffffff),
      cols: (render.width / render.cellWidth).floor().clamp(2, 0x7fffffff),
    );
  }

  /// Resizes the terminal to [proposeDimensions].
  void fit() {
    final dimensions = proposeDimensions();
    if (dimensions != null) {
      terminal.resize(dimensions.cols, dimensions.rows);
    }
  }
}
