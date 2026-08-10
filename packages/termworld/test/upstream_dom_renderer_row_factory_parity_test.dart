import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/core/render_row_factory.dart';
import 'package:vtworld/vtworld.dart';

void main() {
  group('DomRendererRowFactory', () {
    group('createRow', () {
      test('should not create anything for an empty row', () {
        expect(_shape(_line(2)), isEmpty);
      });

      test('should set correct attributes for double width characters', () {
        final line = _line(2)..setCell(0, '語', 2, _attrs());
        expect(
          _shape(line, widths: const <String, double>{'語': 10}).single.text,
          '語',
        );
      });

      test('should add class for cursor and cursor style', () {
        for (final style in <TerminalRowCursorStyle>[
          TerminalRowCursorStyle.block,
          TerminalRowCursorStyle.bar,
          TerminalRowCursorStyle.underline,
        ]) {
          expect(
            _shape(
              _line(2),
              isCursorRow: true,
              cursorStyle: style,
            ).single.cursor,
            style,
          );
        }
      });

      test('should add class for cursor blink', () {
        final span = _shape(
          _line(2),
          isCursorRow: true,
          cursorBlink: true,
        ).single;
        expect(span.cursor, TerminalRowCursorStyle.block);
        expect(span.cursorBlink, isTrue);
      });

      test('should add class for inactive cursor', () {
        for (final style in TerminalRowCursorStyle.values) {
          expect(
            _shape(
              _line(2),
              isCursorRow: true,
              focused: false,
              cursorInactiveStyle: style,
            ).single.cursor,
            style,
          );
        }
      });

      test('should not display cursor for before initializing', () {
        expect(
          _shape(
            _line(2),
            isCursorRow: true,
            cursorInitialized: false,
          ).single.cursor,
          TerminalRowCursorStyle.none,
        );
      });

      group('attributes', () {
        test('should add class for bold', () {
          expect(_styled(bold: true).bold, isTrue);
        });

        test('should add class for italic', () {
          expect(_styled(italic: true).italic, isTrue);
        });

        test('should add class for dim', () {
          expect(_styled(dim: true).dim, isTrue);
        });

        group('underline', () {
          test('should add class for straight underline style', () {
            expect(
              _underlined(TerminalUnderlineStyle.single),
              TerminalUnderlineStyle.single,
            );
          });

          test('should add class for double underline style', () {
            expect(
              _underlined(TerminalUnderlineStyle.double),
              TerminalUnderlineStyle.double,
            );
          });

          test('should add class for curly underline style', () {
            expect(
              _underlined(TerminalUnderlineStyle.curly),
              TerminalUnderlineStyle.curly,
            );
          });

          test('should add class for double dotted style', () {
            expect(
              _underlined(TerminalUnderlineStyle.dotted),
              TerminalUnderlineStyle.dotted,
            );
          });

          test('should add class for dashed underline style', () {
            expect(
              _underlined(TerminalUnderlineStyle.dashed),
              TerminalUnderlineStyle.dashed,
            );
          });
        });

        test('should add class for overline', () {
          expect(_styled(overline: true).overline, isTrue);
        });

        test('should add class for strikethrough', () {
          expect(_styled(strikethrough: true).strikethrough, isTrue);
        });

        test('should hide blinking text when blink is off', () {
          final line = _line(2)..setCell(0, 'a', 1, _attrs(blink: true));
          final info = TerminalRowInfo();
          expect(_shape(line, rowInfo: info).single.style.blinkHidden, isFalse);
          expect(_shape(line, blinkOn: false).single.style.blinkHidden, isTrue);
          expect(info.hasBlinkingCells, isTrue);
        });

        test('should add classes for 256 foreground colors', () {
          for (var index = 0; index < 256; index++) {
            final line = _line(1)
              ..setCell(
                0,
                'a',
                1,
                _attrs(foreground: TerminalCellColor.palette(index)),
              );
            expect(
              _shape(line).single.style.foreground,
              TerminalCellColor.palette(index),
            );
          }
        });

        test('should add classes for 256 background colors', () {
          for (var index = 0; index < 256; index++) {
            final line = _line(1)
              ..setCell(
                0,
                'a',
                1,
                _attrs(background: TerminalCellColor.palette(index)),
              );
            expect(
              _shape(line).single.style.background,
              TerminalCellColor.palette(index),
            );
          }
        });

        test('should correctly invert colors', () {
          final style = _styled(
            inverse: true,
            foreground: const TerminalCellColor.palette(2),
            background: const TerminalCellColor.palette(1),
          );
          expect(style.background, const TerminalCellColor.palette(2));
          expect(style.foreground, const TerminalCellColor.palette(1));
        });

        test('should correctly invert default fg color', () {
          final style = _styled(
            inverse: true,
            background: const TerminalCellColor.palette(1),
          );
          expect(style.background, const TerminalCellColor.palette(257));
          expect(style.foreground, const TerminalCellColor.palette(1));
        });

        test('should correctly invert default bg color', () {
          final style = _styled(
            inverse: true,
            foreground: const TerminalCellColor.palette(1),
          );
          expect(style.background, const TerminalCellColor.palette(1));
          expect(style.foreground, const TerminalCellColor.palette(257));
        });

        test('should turn bold fg text bright', () {
          for (var index = 0; index < 8; index++) {
            expect(
              _styled(
                bold: true,
                foreground: TerminalCellColor.palette(index),
              ).foreground,
              TerminalCellColor.palette(index + 8),
            );
          }
        });

        test('should set style attribute for RBG', () {
          final style = _styled(
            foreground: const TerminalCellColor.rgb(1, 2, 3),
            background: const TerminalCellColor.rgb(4, 5, 6),
          );
          expect(style.foreground.value, 0x010203);
          expect(style.background.value, 0x040506);
        });

        test('should correctly invert RGB colors', () {
          final style = _styled(
            inverse: true,
            foreground: const TerminalCellColor.rgb(1, 2, 3),
            background: const TerminalCellColor.rgb(4, 5, 6),
          );
          expect(style.background.value, 0x010203);
          expect(style.foreground.value, 0x040506);
        });
      });

      group('selectionForeground', () {
        test(
          // The parity verifier requires one literal for this pinned identity.
          // ignore: lines_longer_than_80_chars
          'should force selected cells with content to be rendered above the background',
          () {
            final line = _line(2)
              ..setCell(0, 'a', 1, _attrs())
              ..setCell(1, 'b', 1, _attrs());
            final factory = TerminalRenderRowFactory()
              ..handleSelectionChanged(startX: 1, startY: 0, endX: 2, endY: 0);
            final spans = _shape(line, factory: factory);
            expect(spans.map((span) => span.style.selectionTop), <bool>[
              false,
              true,
            ]);
          },
        );

        test(
          'should force whitespace cells to be rendered above the background',
          () {
            final line = _line(2)..setCell(1, 'a', 1, _attrs());
            final factory = TerminalRenderRowFactory()
              ..handleSelectionChanged(startX: 0, startY: 0, endX: 2, endY: 0);
            final span = _shape(line, factory: factory).single;
            expect(span.text, ' a');
            expect(span.style.selectionTop, isTrue);
          },
        );
      });
    });

    group('createRow with merged spans', () {
      test('should not create anything for an empty row', () {
        expect(_shape(_line(10)), isEmpty);
      });

      test('can merge codepoints for equal spacing', () {
        expect(_shape(_textLine('abc', 10)).single.text, 'abc');
      });

      test('should not merge codepoints with different spacing', () {
        final spans = _shape(
          _textLine('a€c', 10),
          widths: const <String, double>{'€': 2},
        );
        expect(spans.map((span) => span.text), <String>['a', '€', 'c']);
        expect(spans[1].letterSpacing, 3);
      });

      test('should not merge on FG change', () {
        final line = _line(10)
          ..setCell(
            0,
            'a',
            1,
            _attrs(foreground: const TerminalCellColor.palette(1)),
          )
          ..setCell(
            1,
            'a',
            1,
            _attrs(foreground: const TerminalCellColor.palette(1)),
          )
          ..setCell(
            2,
            'b',
            1,
            _attrs(foreground: const TerminalCellColor.palette(2)),
          )
          ..setCell(
            3,
            'b',
            1,
            _attrs(foreground: const TerminalCellColor.palette(2)),
          );
        expect(_shape(line).map((span) => span.text), <String>['aa', 'bb']);
      });

      test('should not merge cursor cell', () {
        final spans = _shape(
          _textLine('aaXbb', 10),
          isCursorRow: true,
          cursorX: 2,
        );
        expect(spans.map((span) => span.text), <String>['aa', 'X', 'bb']);
        expect(spans[1].cursor, TerminalRowCursorStyle.block);
      });

      test('should handle BCE correctly', () {
        final line = _line(10)
          ..setCell(
            2,
            '',
            1,
            _attrs(background: const TerminalCellColor.palette(1)),
          )
          ..setCell(
            3,
            '',
            1,
            _attrs(background: const TerminalCellColor.palette(2)),
          )
          ..setCell(
            4,
            '',
            1,
            _attrs(background: const TerminalCellColor.palette(2)),
          );
        expect(_shape(line).map((span) => span.text), <String>[
          '  ',
          ' ',
          '  ',
        ]);
      });

      test('should handle BCE for multiple cells', () {
        final line = _line(10);
        for (var index = 0; index < 4; index++) {
          line.setCell(
            index,
            '',
            1,
            _attrs(background: const TerminalCellColor.palette(1)),
          );
          expect(_shape(line).single.text.length, index + 1);
        }
        line.setCell(4, 'a', 1, _attrs());
        expect(_shape(line).map((span) => span.text), <String>['    ', 'a']);
      });

      test('should apply correct positive or negative spacing', () {
        final line = _line(10)
          ..setCell(0, 'a', 1, _attrs())
          ..setCell(1, '€', 1, _attrs())
          ..setCell(2, 'c', 1, _attrs())
          ..setCell(3, '語', 2, _attrs())
          ..setCell(5, '𝄞', 1, _attrs());
        final spans = _shape(
          line,
          widths: const <String, double>{'€': 2, '語': 10, '𝄞': 7},
        );
        expect(spans.map((span) => span.text), <String>['a', '€', 'c語', '𝄞']);
        expect(spans.map((span) => span.letterSpacing), <double>[0, 3, 0, -2]);
      });

      test('should not merge across link borders', () {
        final spans = _shape(
          _textLine('aaxxxbb', 10),
          linkStart: 2,
          linkEnd: 4,
        );
        expect(spans.map((span) => span.text), <String>['aa', 'xxx', 'bb']);
        expect(spans[1].style.linkUnderline, isTrue);
      });

      test('empty cells included in link underline', () {
        final line = _line(10)
          ..setCell(0, 'a', 1, _attrs())
          ..setCell(1, 'a', 1, _attrs())
          ..setCell(2, 'x', 1, _attrs())
          ..setCell(4, 'x', 1, _attrs());
        expect(_shape(line, linkStart: 2, linkEnd: 4)[1].text, 'x x');
      });

      test('link range gets capped to actual line borders', () {
        final span = _shape(
          _textLine('aaaaaaaaaa', 10),
          linkStart: -100,
          linkEnd: 100,
        ).single;
        expect(span.text, 'aaaaaaaaaa');
        expect(span.style.linkUnderline, isTrue);
      });
    });
  });
}

TerminalBufferLine _line(int columns) => TerminalBufferLine(columns);

TerminalBufferLine _textLine(String text, int columns) {
  final line = _line(columns);
  var column = 0;
  for (final rune in text.runes) {
    line.setCell(column++, String.fromCharCode(rune), 1, _attrs());
  }
  return line;
}

TerminalCellAttributes _attrs({
  TerminalCellColor foreground = const TerminalCellColor.defaultColor(),
  TerminalCellColor background = const TerminalCellColor.defaultColor(),
  bool bold = false,
  bool dim = false,
  bool italic = false,
  TerminalUnderlineStyle underline = TerminalUnderlineStyle.none,
  bool blink = false,
  bool inverse = false,
  bool strikethrough = false,
  bool overline = false,
}) => TerminalCellAttributes(
  foreground: foreground,
  background: background,
  bold: bold,
  dim: dim,
  italic: italic,
  underline: underline,
  blink: blink,
  inverse: inverse,
  strikethrough: strikethrough,
  overline: overline,
);

TerminalRowStyle _styled({
  TerminalCellColor foreground = const TerminalCellColor.defaultColor(),
  TerminalCellColor background = const TerminalCellColor.defaultColor(),
  bool bold = false,
  bool dim = false,
  bool italic = false,
  bool inverse = false,
  bool strikethrough = false,
  bool overline = false,
}) {
  final line = _line(1)
    ..setCell(
      0,
      'a',
      1,
      _attrs(
        foreground: foreground,
        background: background,
        bold: bold,
        dim: dim,
        italic: italic,
        inverse: inverse,
        strikethrough: strikethrough,
        overline: overline,
      ),
    );
  return _shape(line).single.style;
}

TerminalUnderlineStyle _underlined(TerminalUnderlineStyle style) {
  final line = _line(1)..setCell(0, 'a', 1, _attrs(underline: style));
  return _shape(line).single.style.underline;
}

List<TerminalRowSpan> _shape(
  TerminalBufferLine line, {
  TerminalRenderRowFactory? factory,
  Map<String, double> widths = const <String, double>{},
  bool isCursorRow = false,
  int cursorX = 0,
  TerminalRowCursorStyle cursorStyle = TerminalRowCursorStyle.block,
  TerminalRowCursorStyle cursorInactiveStyle = TerminalRowCursorStyle.outline,
  bool cursorBlink = false,
  bool blinkOn = true,
  bool focused = true,
  bool cursorInitialized = true,
  int linkStart = -1,
  int linkEnd = -1,
  TerminalRowInfo? rowInfo,
}) => (factory ?? TerminalRenderRowFactory()).createRow(
  line,
  row: 0,
  cellWidth: 5,
  measure: (text, {required bold, required italic}) => widths[text] ?? 5,
  isCursorRow: isCursorRow,
  cursorX: cursorX,
  cursorStyle: cursorStyle,
  cursorInactiveStyle: cursorInactiveStyle,
  cursorBlink: cursorBlink,
  blinkOn: blinkOn,
  focused: focused,
  cursorInitialized: cursorInitialized,
  linkStart: linkStart,
  linkEnd: linkEnd,
  rowInfo: rowInfo,
);
