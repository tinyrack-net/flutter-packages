import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/font_family_parser.dart';

void main() {
  group('addon-ligatures - parse', () {
    test('parses individual families', () {
      expect(parseTerminalFontFamilies('monospace'), <String>['monospace']);
    });

    test('parses multiple families', () {
      expect(
        parseTerminalFontFamilies('Arial, Verdana, serif'),
        <String>['Arial', 'Verdana', 'serif'],
      );
    });

    test('parses quoted families', () {
      expect(
        parseTerminalFontFamilies('"Times New Roman", serif'),
        <String>['Times New Roman', 'serif'],
      );
    });

    test('parses single quoted families', () {
      expect(
        parseTerminalFontFamilies("'Times New Roman', serif"),
        <String>['Times New Roman', 'serif'],
      );
    });

    test('parses families with spaces in their names', () {
      expect(
        parseTerminalFontFamilies('Times New Roman, serif'),
        <String>['Times New Roman', 'serif'],
      );
    });

    test('collapses multiple spaces together in identifiers', () {
      expect(
        parseTerminalFontFamilies('Times   New Roman, serif'),
        <String>['Times New Roman', 'serif'],
      );
    });

    test('does not collapse multiple spaces together in quoted strings', () {
      expect(
        parseTerminalFontFamilies('"Times   New Roman", serif'),
        <String>['Times   New Roman', 'serif'],
      );
    });

    test('handles escaped characters in strings', () {
      expect(
        parseTerminalFontFamilies(
          r'"quote \" slash \\ slashquote \\\"", serif',
        ),
        <String>[r'quote " slash \ slashquote \"', 'serif'],
      );
    });

    test('fails if a family has an unterminated string', () {
      expect(
        () => parseTerminalFontFamilies('"Unterminated, serif'),
        throwsFormatException,
      );
    });

    test('handles unicode escape sequences', () {
      expect(
        parseTerminalFontFamilies(r'"space\20 between", serif'),
        <String>['space between', 'serif'],
      );
    });

    test('swallows only the first space after a unicode escape', () {
      expect(
        parseTerminalFontFamilies(r'"two-space\20  between", serif'),
        <String>['two-space  between', 'serif'],
      );
    });

    test('automatically ends the unicode escape after six digits', () {
      expect(
        parseTerminalFontFamilies(r'space\000020between, serif'),
        <String>['space between', 'serif'],
      );
    });

    test('handles unicode escapes at the end of the family', () {
      expect(
        parseTerminalFontFamilies(r'endswithbrace \7b, serif'),
        <String>['endswithbrace {', 'serif'],
      );
    });

    test('handles unicode escapes at the end of the input', () {
      expect(
        parseTerminalFontFamilies(r'endswithbrace \7b'),
        <String>['endswithbrace {'],
      );
    });

    test('handles other escaped characters in identifiers', () {
      expect(parseTerminalFontFamilies(r'has\,comma'), <String>['has,comma']);
    });

    test('swallows escaped newlines in strings', () {
      expect(
        parseTerminalFontFamilies('"multi \\\nline", serif'),
        <String>['multi line', 'serif'],
      );
    });
  });
}
