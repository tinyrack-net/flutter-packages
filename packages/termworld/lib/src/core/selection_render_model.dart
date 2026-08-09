import 'package:termworld/src/core/buffer.dart';

/// Renderer-facing projection of an absolute terminal selection.
final class SelectionRenderModel {
  /// Creates an empty selection model.
  SelectionRenderModel() {
    clear();
  }

  /// Whether the selection intersects the viewport.
  late bool hasSelection;

  /// Whether rectangular column selection is enabled.
  late bool columnSelectMode;

  /// Unclamped first selected viewport row.
  late int viewportStartRow;

  /// Unclamped last selected viewport row.
  late int viewportEndRow;

  /// First selected row clamped to the viewport.
  late int viewportCappedStartRow;

  /// Last selected row clamped to the viewport.
  late int viewportCappedEndRow;

  /// First selection column.
  late int startColumn;

  /// Exclusive last selection column.
  late int endColumn;

  /// Absolute buffer start supplied to [update].
  TerminalBufferPosition? selectionStart;

  /// Absolute buffer end supplied to [update].
  TerminalBufferPosition? selectionEnd;

  /// Restores the empty xterm selection-render state.
  void clear() {
    hasSelection = false;
    columnSelectMode = false;
    viewportStartRow = 0;
    viewportEndRow = 0;
    viewportCappedStartRow = 0;
    viewportCappedEndRow = 0;
    startColumn = 0;
    endColumn = 0;
    selectionStart = null;
    selectionEnd = null;
  }

  /// Projects absolute [start] and [end] positions into the current viewport.
  void update({
    required int rows,
    required int viewportY,
    required TerminalBufferPosition? start,
    required TerminalBufferPosition? end,
    bool columnMode = false,
  }) {
    selectionStart = start;
    selectionEnd = end;
    if (start == null || end == null || start == end) {
      clear();
      return;
    }
    final projectedStart = start.y - viewportY;
    final projectedEnd = end.y - viewportY;
    final cappedStart = projectedStart < 0 ? 0 : projectedStart;
    final lastRow = rows - 1;
    final cappedEnd = projectedEnd > lastRow ? lastRow : projectedEnd;
    if (cappedStart >= rows || cappedEnd < 0) {
      clear();
      return;
    }
    hasSelection = true;
    columnSelectMode = columnMode;
    viewportStartRow = projectedStart;
    viewportEndRow = projectedEnd;
    viewportCappedStartRow = cappedStart;
    viewportCappedEndRow = cappedEnd;
    startColumn = start.x;
    endColumn = end.x;
  }

  /// Reports whether absolute buffer cell ([x], [y]) is selected.
  bool isCellSelected({
    required int x,
    required int y,
    required int viewportY,
  }) {
    if (!hasSelection) return false;
    final projectedY = y - viewportY;
    if (columnSelectMode) {
      if (startColumn <= endColumn) {
        return x >= startColumn &&
            projectedY >= viewportCappedStartRow &&
            x < endColumn &&
            projectedY <= viewportCappedEndRow;
      }
      return x < startColumn &&
          projectedY >= viewportCappedStartRow &&
          x >= endColumn &&
          projectedY <= viewportCappedEndRow;
    }
    return projectedY > viewportStartRow && projectedY < viewportEndRow ||
        viewportStartRow == viewportEndRow &&
            projectedY == viewportStartRow &&
            x >= startColumn &&
            x < endColumn ||
        viewportStartRow < viewportEndRow &&
            projectedY == viewportEndRow &&
            x < endColumn ||
        viewportStartRow < viewportEndRow &&
            projectedY == viewportStartRow &&
            x >= startColumn;
  }
}

/// Creates a cleared xterm-compatible selection render model.
SelectionRenderModel createSelectionRenderModel() => SelectionRenderModel();
