/// HTTP and HTTPS link detection addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/addons/web_links_opener.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/disposable.dart';
import 'package:termworld/src/core/terminal.dart';

/// Link activation callback.
typedef WebLinkActivationHandler = void Function(Object? event, String uri);

/// Optional hover, leave and matching behavior for web links.
final class WebLinkProviderOptions {
  /// Creates web link provider options.
  const WebLinkProviderOptions({this.hover, this.leave, this.urlPattern});

  /// Invoked when a pointer enters a resolved link.
  final void Function(
    Object? event,
    String text,
    TerminalBufferRange range,
  )?
  hover;

  /// Invoked when a pointer leaves a resolved link.
  final void Function(Object? event, String text)? leave;

  /// Optional URL matching expression.
  final RegExp? urlPattern;
}

/// Detects web links in terminal rows.
final class WebLinksAddon extends ManagedTerminalAddon {
  /// Creates a web link addon.
  WebLinksAddon({
    WebLinkActivationHandler? handler,
    this.options = const WebLinkProviderOptions(),
    RegExp? urlPattern,
  }) : handler = handler ?? openWebLink,
       urlPattern =
           options.urlPattern ??
           urlPattern ??
           RegExp(
             r'''https?://[^\s"'!*(){}|\\^<>`]*[^\s"':,.!?{}|\\^~\[\]`()<>]''',
             caseSensitive: false,
           );

  /// xterm-compatible `handler` API.
  final WebLinkActivationHandler handler;

  /// Hover, leave and regex overrides.
  final WebLinkProviderOptions options;

  /// xterm-compatible `urlPattern` API.
  final RegExp urlPattern;
  Disposable? _registration;

  @override
  void onActivate(Terminal terminal) {
    _registration = terminal.registerLinkProvider(
      _WebLinkProvider(terminal, urlPattern, handler, options),
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
  const _WebLinkProvider(
    this.terminal,
    this.pattern,
    this.handler,
    this.options,
  );

  final Terminal terminal;
  final RegExp pattern;
  final WebLinkActivationHandler handler;
  final WebLinkProviderOptions options;

  @override
  List<TerminalLink> provideLinks(int bufferLineNumber) {
    if (bufferLineNumber < 1) return const <TerminalLink>[];
    final window = _windowedLineStrings(bufferLineNumber - 1);
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
    final range = TerminalBufferRange(
      start: TerminalBufferPosition(start.x + 1, start.y + 1),
      end: TerminalBufferPosition(end.x, end.y + 1),
    );
    return TerminalLink(
      range: range,
      text: text,
      activate: handler,
      hover: options.hover == null
          ? null
          : (event, value) => options.hover!(event, value, range),
      leave: options.leave,
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
