/// ANSI and HTML terminal serialization addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/marker.dart';
import 'package:termworld/src/core/options.dart';
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
    this.range,
  });

  /// xterm-compatible `scrollback` API.
  final int? scrollback;

  /// xterm-compatible `onlySelection` API.
  final bool onlySelection;

  /// xterm-compatible `includeGlobalBackground` API.
  final bool includeGlobalBackground;

  /// Explicit active-buffer range. It takes priority over [onlySelection].
  final TerminalHtmlSerializeRange? range;
}

/// Active-buffer range used by HTML serialization.
final class TerminalHtmlSerializeRange {
  /// Creates an inclusive row range starting at [startColumn].
  const TerminalHtmlSerializeRange({
    required this.startLine,
    required this.endLine,
    this.startColumn = 0,
  });

  /// First row to serialize.
  final int startLine;

  /// Last row to serialize.
  final int endLine;

  /// First column on [startLine].
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
    final buffer = terminal.buffer.active;
    late final TerminalBufferPosition start;
    late final TerminalBufferPosition end;
    final requested = options.range;
    if (requested != null) {
      start = TerminalBufferPosition(
        requested.startColumn,
        requested.startLine,
      );
      end = TerminalBufferPosition(terminal.cols, requested.endLine);
    } else if (options.onlySelection) {
      final selection = terminal.getSelectionPosition();
      if (selection == null) return '';
      start = selection.start;
      end = selection.end;
    } else {
      final rows = options.scrollback == null
          ? buffer.length
          : (options.scrollback! + terminal.rows).clamp(0, buffer.length);
      start = TerminalBufferPosition(0, buffer.length - rows);
      end = TerminalBufferPosition(terminal.cols, buffer.length - 1);
    }
    if (start.y < 0 || end.y < start.y || end.y >= buffer.length) {
      throw RangeError('HTML serialization range is outside the active buffer');
    }

    final theme = terminal.options.theme;
    final foreground = options.includeGlobalBackground
        ? theme.foreground ?? '#ffffff'
        : '#000000';
    final background = options.includeGlobalBackground
        ? theme.background ?? '#000000'
        : '#ffffff';
    final output = StringBuffer()
      ..write('<html><body><!--StartFragment--><pre>')
      ..write("<div style='color: $foreground; ")
      ..write('background-color: $background; ')
      ..write('font-family: ${terminal.options.fontFamily}; ')
      ..write("font-size: ${_cssNumber(terminal.options.fontSize)}px;'>");
    final palette = _ansiPalette(theme);
    final empty = buffer.getNullCell();
    for (var row = start.y; row <= end.y; row++) {
      final line = buffer.getLine(row)!;
      final firstColumn = row == start.y ? start.x.clamp(0, line.length) : 0;
      final lastColumn = row == end.y
          ? end.x.clamp(0, line.length)
          : line.length;
      var previous = empty;
      output.write('<div><span>');
      for (var column = firstColumn; column < lastColumn; column++) {
        final cell = line.getCell(column)!;
        if (cell.width == 0) continue;
        if (!cell.attributesEqual(previous)) {
          final styles = _htmlStyles(cell, palette);
          output
            ..write('</span><span')
            ..write(styles.isEmpty ? '>' : " style='${styles.join(' ')}'>");
        }
        output.write(
          cell.chars.isEmpty ? ' ' : _escapeHtmlCell(cell.chars),
        );
        previous = cell;
      }
      output.write('</span></div>');
    }
    return '$output</div></pre><!--EndFragment--></body></html>';
  }

  String _cssNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  String _escapeHtmlCell(String value) =>
      value.replaceAll('&', '&amp;').replaceAll('<', '&lt;');

  List<String> _htmlStyles(TerminalCell cell, List<String> palette) {
    final styles = <String>[];
    final foreground = _htmlColor(
      cell.foregroundMode,
      cell.foreground,
      palette,
    );
    if (foreground != null) styles.add('color: $foreground;');
    final background = _htmlColor(
      cell.backgroundMode,
      cell.background,
      palette,
    );
    if (background != null) styles.add('background-color: $background;');
    if (cell.isInverse) {
      styles.add('color: #000000; background-color: #BFBFBF;');
    }
    if (cell.isBold) styles.add('font-weight: bold;');
    final decorations = <String>[];
    if (cell.isUnderline) {
      decorations.add(
        switch (cell.underlineStyle) {
          TerminalUnderlineStyle.double => 'underline double',
          TerminalUnderlineStyle.curly => 'underline wavy',
          TerminalUnderlineStyle.dotted => 'underline dotted',
          TerminalUnderlineStyle.dashed => 'underline dashed',
          _ => 'underline',
        },
      );
    }
    if (cell.isOverline) decorations.add('overline');
    if (cell.isStrikethrough) decorations.add('line-through');
    if (cell.isBlink) decorations.add('blink');
    if (decorations.isNotEmpty) {
      styles.add('text-decoration: ${decorations.join(' ')};');
    }
    if (cell.isUnderline) {
      final underline = _htmlColor(
        cell.underlineColor.mode,
        cell.underlineColor.value,
        palette,
      );
      if (underline != null) styles.add('text-decoration-color: $underline;');
    }
    if (cell.isInvisible) styles.add('visibility: hidden;');
    if (cell.isItalic) styles.add('font-style: italic;');
    if (cell.isDim) styles.add('opacity: 0.5;');
    return styles;
  }

  String? _htmlColor(
    TerminalColorMode mode,
    int value,
    List<String> palette,
  ) => switch (mode) {
    TerminalColorMode.defaultColor => null,
    TerminalColorMode.palette => palette[value.clamp(0, 255)],
    TerminalColorMode.rgb =>
      '#${value.toRadixString(16).padLeft(6, '0').substring(0, 6)}',
  };

  List<String> _ansiPalette(TerminalColorTheme theme) {
    final colors = <String>[
      '#2e3436',
      '#cc0000',
      '#4e9a06',
      '#c4a000',
      '#3465a4',
      '#75507b',
      '#06989a',
      '#d3d7cf',
      '#555753',
      '#ef2929',
      '#8ae234',
      '#fce94f',
      '#729fcf',
      '#ad7fa8',
      '#34e2e2',
      '#eeeeec',
    ];
    const levels = <int>[0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff];
    for (var index = 0; index < 216; index++) {
      colors.add(
        _rgb(
          levels[index ~/ 36 % 6],
          levels[index ~/ 6 % 6],
          levels[index % 6],
        ),
      );
    }
    for (var index = 0; index < 24; index++) {
      final value = 8 + index * 10;
      colors.add(_rgb(value, value, value));
    }
    final overrides = <String?>[
      theme.black,
      theme.red,
      theme.green,
      theme.yellow,
      theme.blue,
      theme.magenta,
      theme.cyan,
      theme.white,
      theme.brightBlack,
      theme.brightRed,
      theme.brightGreen,
      theme.brightYellow,
      theme.brightBlue,
      theme.brightMagenta,
      theme.brightCyan,
      theme.brightWhite,
    ];
    for (var index = 0; index < overrides.length; index++) {
      if (overrides[index] case final value?) colors[index] = value;
    }
    final extended = theme.extendedAnsi;
    if (extended != null) {
      for (var index = 0; index < extended.length && index < 240; index++) {
        colors[index + 16] = extended[index];
      }
    }
    return colors;
  }

  String _rgb(int red, int green, int blue) =>
      '#${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';

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
}
