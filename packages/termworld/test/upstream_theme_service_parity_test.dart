import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:termworld/termworld.dart';

void main() {
  group('ColorContrastCache', () {
    late ColorContrastCache cache;

    setUp(() => cache = ColorContrastCache());

    test('should save and get color values', () {
      expect(cache.hasColor(1, 0), isFalse);
      cache.setColor(1, 1, null);
      expect(cache.hasColor(1, 1), isTrue);
      cache.setColor(1, 2, const Color(0xff030303));
      expect(cache.getColor(1, 2), const Color(0xff030303));
    });

    test('should save and get css values', () {
      expect(cache.hasCss(1, 0), isFalse);
      cache.setCss(1, 1, null);
      expect(cache.hasCss(1, 1), isTrue);
      cache.setCss(1, 2, '#030303');
      expect(cache.getCss(1, 2), '#030303');
    });

    test('should clear all values on clear', () {
      cache
        ..setColor(1, 1, null)
        ..setCss(1, 1, null)
        ..clear();
      expect(cache.hasColor(1, 1), isFalse);
      expect(cache.hasCss(1, 1), isFalse);
    });
  });

  group('ThemeService', () {
    late TerminalOptions options;
    late TerminalThemeService service;

    setUp(() {
      options = TerminalOptions();
      service = TerminalThemeService(options);
    });

    tearDown(() => service.dispose());

    group('constructor', () {
      test('should fill all colors with values', () {
        final colors = service.colors;
        expect(colors.foreground, isNotNull);
        expect(colors.background, isNotNull);
        expect(colors.cursor, isNotNull);
        expect(colors.cursorAccent, isNotNull);
        expect(colors.selectionBackgroundTransparent, isNotNull);
        expect(colors.selectionBackgroundOpaque, isNotNull);
        expect(colors.selectionInactiveBackgroundTransparent, isNotNull);
        expect(colors.selectionInactiveBackgroundOpaque, isNotNull);
        expect(colors.scrollbarSliderBackground, isNotNull);
        expect(colors.scrollbarSliderHoverBackground, isNotNull);
        expect(colors.scrollbarSliderActiveBackground, isNotNull);
        expect(colors.overviewRulerBorder, isNotNull);
        expect(colors.ansi, hasLength(256));
      });

      test('should fill 240 colors with expected values', () {
        const levels = <int>[0, 95, 135, 175, 215, 255];
        var index = 16;
        for (final red in levels) {
          for (final green in levels) {
            for (final blue in levels) {
              expect(
                service.colors.ansi[index++],
                Color.fromARGB(255, red, green, blue),
              );
            }
          }
        }
        for (var gray = 0; gray < 24; gray++) {
          final channel = 8 + gray * 10;
          expect(
            service.colors.ansi[index++],
            Color.fromARGB(255, channel, channel, channel),
          );
        }
        expect(index, 256);
      });
    });

    group('setTheme', () {
      test('should not throw when not setting all colors', () {
        expect(
          () => options.theme = const TerminalColorTheme(),
          returnsNormally,
        );
      });

      test(
        'should set a partial set of colors, using the default if not present',
        () {
          expect(service.colors.background, const Color(0xff000000));
          expect(service.colors.foreground, const Color(0xffffffff));
          options.theme = const TerminalColorTheme(
            background: '#FF0000',
            foreground: '#00FF00',
          );
          expect(service.colors.background, const Color(0xffff0000));
          expect(service.colors.foreground, const Color(0xff00ff00));
          options.theme = const TerminalColorTheme(background: '#0000FF');
          expect(service.colors.background, const Color(0xff0000ff));
          expect(service.colors.foreground, const Color(0xffffffff));
        },
      );

      test('should set all extended ansi colors in reverse order', () {
        final defaults = List<Color>.of(service.colors.ansi);
        options.theme = TerminalColorTheme(
          extendedAnsi: defaults.reversed.map(_css).toList(),
        );
        for (var index = 16; index <= 255; index++) {
          expect(service.colors.ansi[index], defaults[271 - index]);
        }
      });

      test('should set one extended ansi color and keep the other default', () {
        final defaultSecond = service.colors.ansi[17];
        options.theme = const TerminalColorTheme(
          extendedAnsi: <String>['#ffffff'],
        );
        expect(service.colors.ansi[16], const Color(0xffffffff));
        expect(service.colors.ansi[17], defaultSecond);
      });

      test(
        'should set extended ansi colors to the default when they are unset',
        () {
          final defaultFirst = service.colors.ansi[16];
          options.theme = const TerminalColorTheme(
            extendedAnsi: <String>['#ffffff'],
          );
          expect(service.colors.ansi[16], const Color(0xffffffff));
          options.theme = const TerminalColorTheme(extendedAnsi: <String>[]);
          expect(service.colors.ansi[16], defaultFirst);
          options
            ..theme = const TerminalColorTheme(
              extendedAnsi: <String>['#ffffff'],
            )
            ..theme = const TerminalColorTheme();
          expect(service.colors.ansi[16], defaultFirst);
        },
      );

      test(
        // Exact upstream test title is intentionally preserved for parity.
        // ignore: lines_longer_than_80_chars
        'should set extended ansi colors to the default when they are partially unset',
        () {
          final defaultSecond = service.colors.ansi[17];
          options.theme = const TerminalColorTheme(
            extendedAnsi: <String>['#ffffff', '#000000'],
          );
          expect(service.colors.ansi[17], const Color(0xff000000));
          options.theme = const TerminalColorTheme(
            extendedAnsi: <String>['#ffffff'],
          );
          expect(service.colors.ansi[16], const Color(0xffffffff));
          expect(service.colors.ansi[17], defaultSecond);
        },
      );
    });

    test('modify, restore and contrast-cache lifecycle matches xterm', () {
      final events = <TerminalColorSet>[];
      service.onChangeColors.listen(events.add);
      service.colors.contrastCache.setCss(1, 2, 'cached');
      options.minimumContrastRatio = 2;
      expect(service.colors.contrastCache.hasCss(1, 2), isFalse);

      final original = (
        service.colors.foreground,
        service.colors.background,
        service.colors.cursor,
        service.colors.ansi[1],
      );
      service
        ..modifyColors((colors) {
          colors
            ..foreground = const Color(0xff010101)
            ..background = const Color(0xff020202)
            ..cursor = const Color(0xff030303)
            ..ansi[1] = const Color(0xff040404);
        })
        ..restoreColor(-1)
        ..restoreColor(-2)
        ..restoreColor(-3)
        ..restoreColor(1)
        ..restoreColor()
        ..restoreColor(999);
      expect(service.colors.foreground, original.$1);
      expect(service.colors.background, original.$2);
      expect(service.colors.cursor, original.$3);
      expect(service.colors.ansi[1], original.$4);
      expect(events, isNotEmpty);
      service
        ..dispose()
        ..dispose();
    });
  });
}

String _css(Color color) {
  final value = color.toARGB32() & 0xffffff;
  return '#${value.toRadixString(16).padLeft(6, '0')}';
}
