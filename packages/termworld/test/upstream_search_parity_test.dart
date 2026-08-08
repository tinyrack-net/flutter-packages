import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_search.dart';
import 'package:termworld/termworld_headless.dart';

const _decorations = TerminalSearchDecorationOptions(
  matchOverviewRuler: '#ffff00',
  activeMatchColorOverviewRuler: '#ff0000',
  matchBackground: '#010203',
  matchBorder: '#040506',
  activeMatchBackground: '#070809',
  activeMatchBorder: '#0a0b0c',
);

void main() {
  group('addon-search/test/SearchAddon.test.ts', () {
    late Terminal terminal;
    late SearchAddon search;

    setUp(() {
      terminal = Terminal();
      search = SearchAddon();
      terminal.loadAddon(search);
    });

    tearDown(() => terminal.dispose());

    test('Simple Search and escaped literal search', () async {
      await terminal.writeAndWait(
        'dafhdjfldshafhldsahfkjhldhjkftestlhfdsakjfhdjhlfdsjkafhjdlk',
      );
      expect(search.findNext('test'), isTrue);
      expect(terminal.getSelection(), 'test');

      terminal.reset();
      await terminal.writeAndWait(r'$^1_3{}test$#');
      expect(search.findNext(r'$^1_3{}test$#'), isTrue);
      expect(terminal.getSelection(), r'$^1_3{}test$#');
    });

    test('Incremental Find Next', () async {
      await terminal.writeAndWait(
        'package.lock pack package.json package.ups\r\npackage.jsonc',
      );
      const options = TerminalSearchOptions(incremental: true);
      expect(search.findNext('pack', options: options), isTrue);
      expect(_selectedSuffix(terminal, 8), 'package.lock');
      expect(search.findNext('package.j', options: options), isTrue);
      expect(_selectedSuffix(terminal, 3), 'package.json');
      expect(search.findNext('package.jsonc', options: options), isTrue);
      expect(terminal.getSelection(), 'package.jsonc');
    });

    test('Incremental Find Previous', () async {
      await terminal.writeAndWait(
        'package.jsonc\r\npackage.json pack package.lock',
      );
      const options = TerminalSearchOptions(incremental: true);
      expect(search.findPrevious('pack', options: options), isTrue);
      expect(_selectedSuffix(terminal, 8), 'package.lock');
      expect(search.findPrevious('package.j', options: options), isTrue);
      expect(_selectedSuffix(terminal, 3), 'package.json');
      expect(search.findPrevious('package.jsonc', options: options), isTrue);
      expect(terminal.getSelection(), 'package.jsonc');
    });

    test('regex honors case sensitivity and ignores empty matches', () async {
      await terminal.writeAndWait('abc123defABCD');
      expect(
        search.findNext(
          '[a-z]+',
          options: const TerminalSearchOptions(regex: true),
        ),
        isTrue,
      );
      expect(terminal.getSelection(), 'abc');
      expect(
        search.findNext(
          '[A-Z]+',
          options: const TerminalSearchOptions(
            regex: true,
            caseSensitive: true,
          ),
        ),
        isTrue,
      );
      expect(terminal.getSelection(), 'ABCD');
      expect(
        search.findNext(
          '^',
          options: const TerminalSearchOptions(regex: true),
        ),
        isFalse,
      );
      expect(terminal.hasSelection(), isFalse);
    });

    test('single result remains selected when search wraps', () async {
      await terminal.writeAndWait('abc def');
      expect(search.findNext('abc'), isTrue);
      expect(search.findNext('abc'), isTrue);
      expect(terminal.getSelection(), 'abc');
    });

    test('wide and surrogate characters map to buffer columns', () async {
      await terminal.writeAndWait('中文xx𝄞𝄞');
      expect(search.findNext('中'), isTrue);
      expect(terminal.getSelection(), '中');
      expect(search.findNext('xx'), isTrue);
      expect(terminal.getSelection(), 'xx');
      expect(search.findNext('𝄞'), isTrue);
      expect(terminal.getSelection(), '𝄞');
      expect(search.findNext('𝄞'), isTrue);
      final selection = terminal.getSelectionPosition()!;
      expect(selection.start, const TerminalBufferPosition(7, 0));
      expect(selection.end, const TerminalBufferPosition(8, 0));
    });

    test('wrapped matches select across physical rows', () async {
      terminal.resize(5, 5);
      await terminal.writeAndWait('0123abcdef');
      expect(search.findNext('3abc'), isTrue);
      expect(terminal.getSelection(), '3abc');
      final selection = terminal.getSelectionPosition()!;
      expect(selection.start, const TerminalBufferPosition(3, 0));
      expect(selection.end, const TerminalBufferPosition(2, 1));
    });

    test('whole word uses xterm non-word character set', () async {
      await terminal.writeAndWait('foo foobar foo_bar (foo)');
      const options = TerminalSearchOptions(wholeWord: true);
      expect(search.findNext('foo', options: options), isTrue);
      expect(terminal.getSelectionPosition()!.start.x, 0);
      expect(search.findNext('foo', options: options), isTrue);
      expect(terminal.getSelectionPosition()!.start.x, 20);
      expect(search.findNext('foo', options: options), isTrue);
      expect(terminal.getSelectionPosition()!.start.x, 0);
    });

    test('result events and decorations match forward cycling', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('abc bc c');
      expect(search.findNext('a'), isTrue);
      expect(events, isEmpty);

      const options = TerminalSearchOptions(decorations: _decorations);
      expect(search.findNext('b', options: options), isTrue);
      expect(search.findNext('d', options: options), isFalse);
      expect(search.findNext('c', options: options), isTrue);
      expect(search.findNext('c', options: options), isTrue);
      expect(search.findNext('c', options: options), isTrue);
      expect(
        events.map((event) => (event.resultCount, event.resultIndex)),
        <(int, int)>[(2, 0), (0, -1), (3, 0), (3, 1), (3, 2)],
      );
      expect(terminal.decorations, isNotEmpty);
      expect(
        terminal.decorations.any(
          (value) =>
              value.layer == TerminalDecorationLayer.top &&
              value.borderColor == '#0a0b0c' &&
              value.overviewRulerColor == '#ff0000',
        ),
        isTrue,
      );
      search.clearActiveDecoration();
      expect(
        terminal.decorations.every(
          (value) => value.layer == TerminalDecorationLayer.bottom,
        ),
        isTrue,
      );
      search.clearDecorations();
      expect(terminal.decorations, isEmpty);
    });

    test('highlight limit reports only tracked matches', () async {
      search.dispose();
      search = SearchAddon(highlightLimit: 2);
      terminal.loadAddon(search);
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('a a a');
      const options = TerminalSearchOptions(decorations: _decorations);
      expect(search.findPrevious('a', options: options), isTrue);
      expect((events.single.resultCount, events.single.resultIndex), (2, -1));
    });

    test('before and after events are synchronous and balanced', () async {
      final events = <String>[];
      search.onBeforeSearch.listen((_) => events.add('before'));
      search.onAfterSearch.listen((_) => events.add('after'));
      await terminal.writeAndWait('abc abc');
      expect(search.findNext('abc'), isTrue);
      expect(search.findPrevious('abc'), isTrue);
      expect(events, <String>['before', 'after', 'before', 'after']);
    });

    test('empty search and no match clear selection', () async {
      await terminal.writeAndWait('abc');
      terminal.select(0, 0, 1);
      expect(search.findNext(''), isFalse);
      expect(terminal.hasSelection(), isFalse);
      terminal.select(0, 0, 1);
      expect(search.findPrevious('missing'), isFalse);
      expect(terminal.hasSelection(), isFalse);
    });
  });
}

String _selectedSuffix(Terminal terminal, int trailingLength) {
  final selection = terminal.getSelectionPosition()!;
  final line = terminal.buffer.active
      .getLine(selection.start.y)!
      .translateToString(trimRight: true);
  final end = (selection.end.x + trailingLength).clamp(0, line.length);
  return line.substring(selection.start.x, end);
}
