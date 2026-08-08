/// HTTP and HTTPS link detection addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/terminal.dart';

/// Link activation callback.
typedef TerminalLinkHandler = void Function(String uri);

/// Detects web links in terminal rows.
final class WebLinksAddon extends ManagedTerminalAddon {
  /// Creates a web link addon.
  WebLinksAddon({
    required this.handler,
    RegExp? urlPattern,
  }) : urlPattern =
           urlPattern ??
           RegExp(
             r'''https?://[^\s"'!*(){}|\\^<>`]*[^\s"':,.!?{}|\\^~\[\]`()<>]''',
             caseSensitive: false,
           );

  /// xterm-compatible `handler` API.
  final TerminalLinkHandler handler;

  /// xterm-compatible `urlPattern` API.
  final RegExp urlPattern;
  Disposable? _registration;

  @override
  void onActivate(Terminal terminal) {
    _registration = terminal.registerLinkProvider(
      _WebLinkProvider(terminal, urlPattern, handler),
    );
  }

  @override
  void dispose() {
    _registration?.dispose();
    _registration = null;
    super.dispose();
  }
}

final class _WebLinkProvider implements TerminalLinkProvider {
  const _WebLinkProvider(this.terminal, this.pattern, this.handler);

  final Terminal terminal;
  final RegExp pattern;
  final TerminalLinkHandler handler;

  @override
  List<TerminalLink> provideLinks(int bufferLineNumber) {
    final window = _windowedLineStrings(bufferLineNumber);
    final text = window.lines.join();
    if (text.isEmpty) return const <TerminalLink>[];
    final links = <TerminalLink>[];
    for (final match in pattern.allMatches(text)) {
      if (!(Uri.tryParse(match.group(0)!)?.hasAuthority ?? false)) continue;
      final link = _linkForMatch(window.startLine, match);
      if (link != null) links.add(link);
    }
    return links;
  }

  TerminalLink? _linkForMatch(int startLine, RegExpMatch match) {
    final text = match.group(0)!;
    final start = _mapStringIndex(startLine, 0, match.start);
    final end = _mapStringIndex(start.y, start.x, text.length);
    if (start.x < 0 || start.y < 0 || end.x < 0 || end.y < 0) return null;
    return TerminalLink(
      range: TerminalBufferRange(
        start: TerminalBufferPosition(start.x + 1, start.y + 1),
        end: TerminalBufferPosition(end.x, end.y + 1),
      ),
      text: text,
      activate: handler,
    );
  }

  ({List<String> lines, int startLine}) _windowedLineStrings(int lineIndex) {
    final buffer = terminal.buffer.active;
    var top = lineIndex;
    var bottom = lineIndex;
    final lines = <String>[];
    final current = buffer.getLine(lineIndex);
    if (current == null) return (lines: lines, startLine: top);
    final currentContent = current.translateToString(trimRight: true);

    if (current.isWrapped && !currentContent.startsWith(' ')) {
      var length = 0;
      while (length < 2048) {
        top--;
        final line = buffer.getLine(top);
        if (line == null) break;
        final content = line.translateToString(trimRight: true);
        length += content.length;
        lines.add(content);
        if (!line.isWrapped || content.contains(' ')) break;
      }
      lines.setAll(0, lines.reversed.toList(growable: false));
    }

    lines.add(currentContent);
    var length = 0;
    while (length < 2048) {
      bottom++;
      final line = buffer.getLine(bottom);
      if (line == null || !line.isWrapped) break;
      final content = line.translateToString(trimRight: true);
      length += content.length;
      lines.add(content);
      if (content.contains(' ')) break;
    }
    return (lines: lines, startLine: top);
  }

  ({int y, int x}) _mapStringIndex(
    int lineIndex,
    int rowIndex,
    int stringIndex,
  ) {
    final buffer = terminal.buffer.active;
    var currentLine = lineIndex;
    var remaining = stringIndex;
    var start = rowIndex;
    while (remaining != 0) {
      final line = buffer.getLine(currentLine);
      if (line == null) return (y: -1, x: -1);
      for (var column = start; column < line.length; column++) {
        final cell = line.getCell(column)!;
        if (cell.width != 0) {
          remaining -= cell.chars.isEmpty ? 1 : cell.chars.length;
          if (column == line.length - 1 && cell.chars.isEmpty) {
            final nextLine = buffer.getLine(currentLine + 1);
            if (nextLine != null &&
                nextLine.isWrapped &&
                nextLine.getCell(0)!.width == 2) {
              remaining++;
            }
          }
        }
        if (remaining < 0) return (y: currentLine, x: column);
      }
      currentLine++;
      start = 0;
    }
    return (y: currentLine, x: start);
  }
}
