/// Parses a CSS font-family value into its component family names.
List<String> parseTerminalFontFamilies(String input) {
  final context = _FontFamilyParseContext(input);
  final families = <String>[];
  var currentFamily = '';
  while (context.offset < input.length) {
    final character = input[context.offset++];
    switch (character) {
      case "'":
      case '"':
        currentFamily += _parseString(context, character);
      case ',':
        families.add(currentFamily);
        currentFamily = '';
      default:
        if (!_isWhitespace(character)) {
          context.offset--;
          currentFamily += _parseIdentifier(context);
          families.add(currentFamily);
          currentFamily = '';
        }
    }
  }
  return families;
}

/// Whether [family] is one of the CSS Fonts level 4 generic families used by
/// xterm's local-font resolver as a resolution boundary.
bool isTerminalGenericFontFamily(String family) =>
    _genericFontFamilies.contains(family);

const Set<String> _genericFontFamilies = <String>{
  'serif',
  'sans-serif',
  'cursive',
  'fantasy',
  'monospace',
  'system-ui',
  'emoji',
  'math',
  'fangsong',
};

final class _FontFamilyParseContext {
  _FontFamilyParseContext(this.input);

  final String input;
  int offset = 0;
}

String _parseString(_FontFamilyParseContext context, String quote) {
  final result = StringBuffer();
  var escaped = false;
  while (context.offset < context.input.length) {
    final character = context.input[context.offset++];
    if (escaped) {
      if (_isHex(character)) {
        context.offset--;
        result.write(_parseUnicode(context));
      } else if (character != '\n') {
        result.write(character);
      }
      escaped = false;
      continue;
    }
    if (character == quote) return result.toString();
    if (character == r'\') {
      escaped = true;
    } else {
      result.write(character);
    }
  }
  throw FormatException('Unterminated string', context.input);
}

String _parseIdentifier(_FontFamilyParseContext context) {
  final result = StringBuffer();
  var escaped = false;
  while (context.offset < context.input.length) {
    final character = context.input[context.offset++];
    if (escaped) {
      if (_isHex(character)) {
        context.offset--;
        result.write(_parseUnicode(context));
      } else {
        result.write(character);
      }
      escaped = false;
      continue;
    }
    if (character == r'\') {
      escaped = true;
    } else if (character == ',') {
      return result.toString();
    } else if (_isWhitespace(character)) {
      if (!result.toString().endsWith(' ')) result.write(' ');
    } else {
      result.write(character);
    }
  }
  return result.toString();
}

String _parseUnicode(_FontFamilyParseContext context) {
  final digits = StringBuffer();
  while (context.offset < context.input.length) {
    final character = context.input[context.offset++];
    if (_isWhitespace(character)) return _unicodeToString(digits.toString());
    if (digits.length >= 6 || !_isHex(character)) {
      context.offset--;
      return _unicodeToString(digits.toString());
    }
    digits.write(character);
  }
  return _unicodeToString(digits.toString());
}

String _unicodeToString(String digits) =>
    String.fromCharCode(int.parse(digits, radix: 16));

bool _isWhitespace(String value) => RegExp(r'\s').hasMatch(value);

bool _isHex(String value) => RegExp('[0-9A-Fa-f]').hasMatch(value);
