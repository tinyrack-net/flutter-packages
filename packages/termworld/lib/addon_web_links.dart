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
    final line = terminal.buffer.active.getLine(bufferLineNumber);
    if (line == null) return const <TerminalLink>[];
    final text = line.translateToString(trimRight: true);
    return <TerminalLink>[
      for (final match in pattern.allMatches(text))
        if (Uri.tryParse(match.group(0)!)?.hasAuthority ?? false)
          TerminalLink(
            range: TerminalBufferRange(
              start: TerminalBufferPosition(
                match.start + 1,
                bufferLineNumber + 1,
              ),
              end: TerminalBufferPosition(match.end, bufferLineNumber + 1),
            ),
            text: match.group(0)!,
            activate: handler,
          ),
    ];
  }
}
