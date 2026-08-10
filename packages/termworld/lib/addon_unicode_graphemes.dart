/// Unicode 15 grapheme-width addon.
library;

import 'package:vtworld/vtworld.dart';

part 'unicode15_properties.g.dart';

/// Unicode 15 provider with optional extended grapheme joining.
final class UnicodeGraphemeProvider implements TerminalUnicodeProvider {
  /// xterm-compatible `UnicodeGraphemeProvider` API.
  UnicodeGraphemeProvider({this.handleGraphemes = true});

  /// xterm-compatible `handleGraphemes` API.
  final bool handleGraphemes;

  /// Whether East Asian ambiguous characters occupy two cells.
  bool ambiguousCharsAreWide = false;

  @override
  String get version => handleGraphemes ? '15-graphemes' : '15';

  @override
  int width(int codePoint) {
    final info = _unicode15Info(codePoint);
    final kind = info & 0xf;
    if (kind == 2 || kind == 1) return 0;
    final widthInfo = info >> 4 & 3;
    return widthInfo >= 3 || widthInfo == 2 && ambiguousCharsAreWide ? 2 : 1;
  }

  @override
  int charProperties(int codePoint, int precedingProperties) {
    if (codePoint >= 32 &&
        codePoint < 127 &&
        TerminalUnicodeHandling.extractCharKind(precedingProperties) == 0) {
      return TerminalUnicodeHandling.createPropertyValue(0, 1);
    }
    var info = _unicode15Info(codePoint);
    var cellWidth = info >> 4 & 3;
    cellWidth = cellWidth >= 2
        ? cellWidth == 3 || ambiguousCharsAreWide || codePoint == 0xfe0f
              ? 2
              : 1
        : 1;
    var shouldJoin = false;
    if (precedingProperties != 0) {
      final oldWidth = TerminalUnicodeHandling.extractWidth(
        precedingProperties,
      );
      if (handleGraphemes) {
        info = _shouldJoin(
          TerminalUnicodeHandling.extractCharKind(precedingProperties),
          info,
        );
      } else {
        info = cellWidth == 0 ? 1 : 0;
      }
      shouldJoin = info > 0;
      if (shouldJoin) {
        if (oldWidth > cellWidth) {
          cellWidth = oldWidth;
        } else if (info == 32) {
          cellWidth = 2;
        }
      }
    }
    return TerminalUnicodeHandling.createPropertyValue(
      info,
      cellWidth,
      shouldJoin: shouldJoin,
    );
  }

  static int _shouldJoin(int beforeState, int afterInfo) {
    final before = beforeState & 0xf;
    final after = afterInfo & 0xf;
    var joins = false;
    if (before >= 5 && before <= 9) {
      joins =
          before == 5 &&
              (after == 5 || after == 6 || after == 8 || after == 9) ||
          (before == 8 || before == 6) && (after == 6 || after == 7) ||
          (before == 9 || before == 7) && after == 7;
    }
    joins =
        joins ||
        after == 2 ||
        after == 10 ||
        before == 1 ||
        after == 4 ||
        before == 10 && after == 11 ||
        after == 3 && before == 3;
    if (!joins) return after - 16;
    return after == 3 ? 32 : after + 16;
  }

  static int _unicode15Info(int codePoint) {
    if (codePoint < 0 || codePoint > 0x10ffff) return 0;
    var low = 0;
    var high = _unicode15Properties.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final range = _unicode15Properties[middle];
      if (codePoint < range.$1) {
        high = middle - 1;
      } else if (codePoint > range.$2) {
        low = middle + 1;
      } else {
        return range.$3;
      }
    }
    return 0;
  }
}

/// Registers Unicode 15 and Unicode 15 grapheme-aware providers.
final class UnicodeGraphemesAddon extends ManagedTerminalAddon {
  String? _previous;

  @override
  void onActivate(Terminal terminal) {
    _previous = terminal.unicode.activeVersion;
    for (final provider in <UnicodeGraphemeProvider>[
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
    if (isDisposed) return;
    final previous = _previous;
    if (previous != null && isActive) terminal.unicode.activeVersion = previous;
    _previous = null;
    super.dispose();
  }
}
