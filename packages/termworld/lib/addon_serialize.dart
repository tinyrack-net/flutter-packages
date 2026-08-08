/// ANSI and HTML terminal serialization addon.
library;

import 'dart:convert';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/marker.dart';
import 'package:termworld/src/core/terminal.dart';

/// Inclusive line range used for ANSI serialization.
final class TerminalSerializeRange {
  /// xterm-compatible `TerminalSerializeRange` API.
  const TerminalSerializeRange({required this.start, required this.end});

  /// xterm-compatible `start` API.
  final Object start;

  /// xterm-compatible `end` API.
  final Object end;
}

/// ANSI serialization controls.
final class TerminalSerializeOptions {
  /// xterm-compatible `TerminalSerializeOptions` API.
  const TerminalSerializeOptions({
    this.range,
    this.scrollback,
    this.excludeModes = false,
    this.excludeAltBuffer = false,
  });

  /// xterm-compatible `range` API.
  final TerminalSerializeRange? range;

  /// xterm-compatible `scrollback` API.
  final int? scrollback;

  /// xterm-compatible `excludeModes` API.
  final bool excludeModes;

  /// xterm-compatible `excludeAltBuffer` API.
  final bool excludeAltBuffer;
}

/// HTML serialization controls.
final class TerminalHtmlSerializeOptions {
  /// xterm-compatible `TerminalHtmlSerializeOptions` API.
  const TerminalHtmlSerializeOptions({
    this.scrollback,
    this.onlySelection = false,
    this.includeGlobalBackground = false,
    this.startLine,
    this.endLine,
    this.startColumn = 0,
  });

  /// xterm-compatible `scrollback` API.
  final int? scrollback;

  /// xterm-compatible `onlySelection` API.
  final bool onlySelection;

  /// xterm-compatible `includeGlobalBackground` API.
  final bool includeGlobalBackground;

  /// xterm-compatible `startLine` API.
  final int? startLine;

  /// xterm-compatible `endLine` API.
  final int? endLine;

  /// xterm-compatible `startColumn` API.
  final int startColumn;
}

/// Serializes the current buffer so it can be restored or copied.
final class SerializeAddon extends ManagedTerminalAddon {
  @override
  void onActivate(Terminal terminal) {}

  /// Serializes visible and retained rows as ANSI text.
  String serialize({
    TerminalSerializeOptions options = const TerminalSerializeOptions(),
  }) {
    final normal = terminal.buffer.normal;
    final range = _lineRange(normal, options.range, options.scrollback);
    final normalEnd = _contentEnd(normal, range.$1, range.$2);
    final result = StringBuffer();
    for (var row = range.$1; row <= normalEnd; row++) {
      _serializeLine(normal.getLine(row)!, result);
      if (row != normalEnd) result.write('\r\n');
    }
    if (!options.excludeAltBuffer &&
        identical(terminal.buffer.active, terminal.buffer.alternate)) {
      result.write('\u001b[?1049h\u001b[H');
      final alternate = terminal.buffer.alternate;
      final alternateEnd = _contentEnd(alternate, 0, alternate.length - 1);
      for (var row = 0; row <= alternateEnd; row++) {
        _serializeLine(alternate.getLine(row)!, result);
        if (row != alternateEnd) result.write('\r\n');
      }
    }
    if (!options.excludeModes) _serializeModes(result);
    return result.toString();
  }

  /// Serializes the active buffer or current selection as safe HTML.
  String serializeAsHtml({
    TerminalHtmlSerializeOptions options = const TerminalHtmlSerializeOptions(),
  }) {
    final selected = options.onlySelection ? terminal.getSelection() : '';
    final content = selected.isNotEmpty
        ? selected
        : _plainRange(
            options.startLine,
            options.endLine,
            options.scrollback,
            options.startColumn,
          );
    final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(content);
    final background = options.includeGlobalBackground
        ? ' style="background:#000;color:#fff"'
        : '';
    return '<pre$background>$escaped</pre>';
  }

  (int, int) _lineRange(
    TerminalBuffer buffer,
    TerminalSerializeRange? requested,
    int? scrollback,
  ) {
    var start = 0;
    var end = buffer.length - 1;
    if (requested != null) {
      start = _line(requested.start);
      end = _line(requested.end);
    } else if (scrollback != null) {
      if (scrollback < 0) throw ArgumentError.value(scrollback, 'scrollback');
      start = (buffer.baseY - scrollback).clamp(0, end);
    }
    if (start < 0 || end < start || end >= buffer.length) {
      throw RangeError('Serialization range is outside the active buffer');
    }
    return (start, end);
  }

  int _line(Object value) => switch (value) {
    final int line => line,
    final TerminalMarker marker => marker.line,
    _ => throw ArgumentError.value(value, 'range', 'must use marker or int'),
  };

  int _contentEnd(TerminalBuffer buffer, int start, int requestedEnd) {
    for (var row = requestedEnd; row > start; row--) {
      final line = buffer.getLine(row)!;
      if (_serializedLength(line) != 0 || row == buffer.absoluteCursorY) {
        return row;
      }
    }
    return start;
  }

  void _serializeLine(TerminalBufferLine line, StringBuffer result) {
    var attributes = '';
    final end = _serializedLength(line);
    for (var column = 0; column < end; column++) {
      final cell = line.getCell(column)!;
      if (cell.width == 0) continue;
      final nextAttributes = _sgr(cell);
      if (nextAttributes != attributes) {
        result.write('\u001b[0m$nextAttributes');
        attributes = nextAttributes;
      }
      result.write(cell.chars.isEmpty ? ' ' : cell.chars);
    }
    if (attributes.isNotEmpty) result.write('\u001b[0m');
  }

  int _serializedLength(TerminalBufferLine line) {
    for (var column = line.length - 1; column >= 0; column--) {
      final cell = line.getCell(column)!;
      if (cell.chars.isNotEmpty || !cell.isAttributeDefault) return column + 1;
    }
    return 0;
  }

  String _sgr(TerminalCell cell) {
    final codes = <String>[];
    if (cell.isBold) codes.add('1');
    if (cell.isDim) codes.add('2');
    if (cell.isItalic) codes.add('3');
    if (cell.isUnderline) codes.add('4');
    if (cell.isBlink) codes.add('5');
    if (cell.isInverse) codes.add('7');
    if (cell.isInvisible) codes.add('8');
    if (cell.isStrikethrough) codes.add('9');
    if (cell.foregroundMode == TerminalColorMode.rgb) {
      codes.add(
        '38;2;${cell.foreground >> 16};'
        '${cell.foreground >> 8 & 255};${cell.foreground & 255}',
      );
    } else if (cell.foregroundMode == TerminalColorMode.palette) {
      codes.add('38;5;${cell.foreground}');
    }
    if (cell.backgroundMode == TerminalColorMode.rgb) {
      codes.add(
        '48;2;${cell.background >> 16};'
        '${cell.background >> 8 & 255};${cell.background & 255}',
      );
    } else if (cell.backgroundMode == TerminalColorMode.palette) {
      codes.add('48;5;${cell.background}');
    }
    return codes.isEmpty ? '' : '\u001b[${codes.join(';')}m';
  }

  void _serializeModes(StringBuffer result) {
    final modes = terminal.modes;
    if (modes.applicationCursorKeysMode) result.write('\u001b[?1h');
    if (modes.applicationKeypadMode) result.write('\u001b[?66h');
    if (modes.bracketedPasteMode) result.write('\u001b[?2004h');
    if (modes.insertMode) result.write('\u001b[4h');
    if (modes.originMode) result.write('\u001b[?6h');
    if (modes.reverseWraparoundMode) result.write('\u001b[?45h');
    if (modes.sendFocusMode) result.write('\u001b[?1004h');
    if (!modes.showCursor) result.write('\u001b[?25l');
    if (!modes.wraparoundMode) result.write('\u001b[?7l');
    switch (modes.mouseTrackingMode) {
      case 'x10':
        result.write('\u001b[?9h');
      case 'vt200':
        result.write('\u001b[?1000h');
      case 'drag':
        result.write('\u001b[?1002h');
      case 'any':
        result.write('\u001b[?1003h');
      case 'none':
        break;
    }
  }

  String _plainRange(
    int? startLine,
    int? endLine,
    int? scrollback,
    int startColumn,
  ) {
    final buffer = terminal.buffer.active;
    final start =
        startLine ??
        (scrollback == null
            ? 0
            : (buffer.baseY - scrollback).clamp(0, buffer.length));
    final end = endLine ?? buffer.length - 1;
    final output = StringBuffer();
    for (var row = start; row <= end; row++) {
      output.write(
        buffer
            .getLine(row)!
            .translateToString(
              trimRight: true,
              startColumn: row == start ? startColumn : 0,
            ),
      );
      if (row != end) output.write('\n');
    }
    return output.toString();
  }
}
