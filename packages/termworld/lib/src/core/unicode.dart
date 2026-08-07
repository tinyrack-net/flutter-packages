import 'package:characters/characters.dart';

/// Supplies character width and grapheme continuation properties.
abstract interface class TerminalUnicodeProvider {
  /// xterm-compatible `version` API.
  String get version;

  /// xterm-compatible `width` API.
  int width(int codePoint);

  /// xterm-compatible `charProperties` API.
  int charProperties(int codePoint, int precedingProperties);
}

/// Registry for selectable Unicode width providers.
final class TerminalUnicodeHandling {
  /// xterm-compatible `TerminalUnicodeHandling` API.
  TerminalUnicodeHandling() {
    register(const Unicode11TerminalProvider());
  }

  final Map<String, TerminalUnicodeProvider> _providers =
      <String, TerminalUnicodeProvider>{};
  String _activeVersion = '11';

  /// xterm-compatible `register` API.
  void register(TerminalUnicodeProvider provider) {
    if (_providers.containsKey(provider.version)) {
      throw ArgumentError.value(
        provider.version,
        'provider.version',
        'has already been registered',
      );
    }
    _providers[provider.version] = provider;
  }

  /// xterm-compatible `unmodifiable` API.
  List<String> get versions => List<String>.unmodifiable(_providers.keys);

  /// xterm-compatible `activeVersion` API.
  String get activeVersion => _activeVersion;

  /// xterm-compatible `activeVersion` API.
  set activeVersion(String value) {
    if (!_providers.containsKey(value)) {
      throw ArgumentError.value(value, 'activeVersion', 'is not registered');
    }
    _activeVersion = value;
  }

  /// xterm-compatible `active` API.
  TerminalUnicodeProvider get active => _providers[_activeVersion]!;
}

/// Unicode 11 width provider matching xterm's default table at its boundaries.
final class Unicode11TerminalProvider implements TerminalUnicodeProvider {
  /// xterm-compatible `Unicode11TerminalProvider` API.
  const Unicode11TerminalProvider();

  @override
  String get version => '11';

  @override
  int charProperties(int codePoint, int precedingProperties) =>
      width(codePoint);

  @override
  int width(int codePoint) {
    if (codePoint == 0 ||
        codePoint < 0x20 ||
        (codePoint >= 0x7f && codePoint < 0xa0)) {
      return 0;
    }
    final value = String.fromCharCode(codePoint);
    if (value.characters.isEmpty) return 0;
    if (_isCombining(codePoint)) return 0;
    return _isWide(codePoint) ? 2 : 1;
  }

  static bool _isCombining(int rune) =>
      (rune >= 0x0300 && rune <= 0x036f) ||
      (rune >= 0x1ab0 && rune <= 0x1aff) ||
      (rune >= 0x1dc0 && rune <= 0x1dff) ||
      (rune >= 0x20d0 && rune <= 0x20ff) ||
      (rune >= 0xfe20 && rune <= 0xfe2f) ||
      rune == 0x200d ||
      (rune >= 0xfe00 && rune <= 0xfe0f);

  static bool _isWide(int rune) =>
      (rune >= 0x1100 && rune <= 0x115f) ||
      (rune >= 0x2329 && rune <= 0x232a) ||
      (rune >= 0x2e80 && rune <= 0xa4cf && rune != 0x303f) ||
      (rune >= 0xac00 && rune <= 0xd7a3) ||
      (rune >= 0xf900 && rune <= 0xfaff) ||
      (rune >= 0xfe10 && rune <= 0xfe19) ||
      (rune >= 0xfe30 && rune <= 0xfe6f) ||
      (rune >= 0xff00 && rune <= 0xff60) ||
      (rune >= 0xffe0 && rune <= 0xffe6) ||
      (rune >= 0x1f300 && rune <= 0x1faff) ||
      (rune >= 0x20000 && rune <= 0x3fffd);
}
