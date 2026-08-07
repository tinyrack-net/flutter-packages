/// Unicode 15 grapheme-width addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:termworld/src/core/unicode.dart';

/// Unicode 15 provider with optional extended grapheme joining.
final class UnicodeGraphemeProvider implements TerminalUnicodeProvider {
  /// xterm-compatible `UnicodeGraphemeProvider` API.
  const UnicodeGraphemeProvider({this.handleGraphemes = true});

  /// xterm-compatible `handleGraphemes` API.
  final bool handleGraphemes;

  @override
  String get version => handleGraphemes ? '15-graphemes' : '15';

  @override
  int width(int codePoint) =>
      const Unicode11TerminalProvider().width(codePoint);

  @override
  int charProperties(int codePoint, int precedingProperties) {
    final currentWidth = width(codePoint);
    if (!handleGraphemes || precedingProperties == 0) return currentWidth;
    if (currentWidth == 0 || codePoint == 0x200d || codePoint == 0xfe0f) {
      return precedingProperties;
    }
    return currentWidth;
  }
}

/// Registers Unicode 15 and Unicode 15 grapheme-aware providers.
final class UnicodeGraphemesAddon extends ManagedTerminalAddon {
  String? _previous;

  @override
  void onActivate(Terminal terminal) {
    _previous = terminal.unicode.activeVersion;
    for (final provider in const <UnicodeGraphemeProvider>[
      UnicodeGraphemeProvider(handleGraphemes: false),
      UnicodeGraphemeProvider(),
    ]) {
      if (!terminal.unicode.versions.contains(provider.version)) {
        terminal.unicode.register(provider);
      }
    }
    terminal.unicode.activeVersion = '15-graphemes';
  }

  @override
  void dispose() {
    final previous = _previous;
    if (previous != null && isActive) terminal.unicode.activeVersion = previous;
    _previous = null;
    super.dispose();
  }
}
