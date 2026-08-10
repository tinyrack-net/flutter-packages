/// Terminal dimension fitting addon.
library;

import 'package:flutter/foundation.dart';
import 'package:vtworld/vtworld.dart';

/// Proposed terminal row and column count.
@immutable
final class TerminalDimensions {
  /// xterm-compatible `TerminalDimensions` API.
  const TerminalDimensions({required this.rows, required this.cols});

  /// Rows that fit the renderer.
  final int rows;

  /// Columns that fit the renderer.
  final int cols;

  @override
  bool operator ==(Object other) =>
      other is TerminalDimensions && other.rows == rows && other.cols == cols;

  @override
  int get hashCode => Object.hash(rows, cols);
}

/// Fits the terminal buffer to its latest measured Flutter render surface.
final class FitAddon extends ManagedTerminalAddon {
  Terminal? _fitTerminal;

  @override
  void onActivate(Terminal terminal) {
    _fitTerminal = terminal;
  }

  /// Returns the dimensions that fit, or null before the view is measured.
  TerminalDimensions? proposeDimensions() {
    final target = _fitTerminal;
    if (target == null) return null;
    final render = target.dimensions;
    if (render == null || render.cellWidth <= 0 || render.cellHeight <= 0) {
      return null;
    }
    final scrollbarWidth =
        target.options.scrollback == 0 ||
            !target.options.scrollbar.showScrollbar
        ? 0
        : target.options.scrollbar.width ?? 14;
    return TerminalDimensions(
      rows: (render.height / render.cellHeight).floor().clamp(1, 0x7fffffff),
      cols: ((render.width - scrollbarWidth) / render.cellWidth).floor().clamp(
        2,
        0x7fffffff,
      ),
    );
  }

  /// Resizes the terminal to [proposeDimensions].
  void fit() {
    final dimensions = proposeDimensions();
    final target = _fitTerminal;
    if (dimensions != null && target != null) {
      target.resize(dimensions.cols, dimensions.rows);
    }
  }
}
