import 'dart:io';

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

    test('xterm SearchAddon Simple Search', () async {
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

    test('xterm SearchAddon Scrolling Search', () async {
      final data = StringBuffer();
      for (var row = 0; row < 100; row++) {
        if (row == 52) data.write(r'$^1_3{}test$#');
        data.write('${'x' * 50}\r\n');
      }
      await terminal.writeAndWait(data.toString());
      expect(search.findNext(r'$^1_3{}test$#'), isTrue);
      expect(terminal.getSelection(), r'$^1_3{}test$#');
      final selectedRow = terminal.getSelectionPosition()!.start.y;
      expect(
        selectedRow,
        inInclusiveRange(terminal.viewportY, terminal.viewportY + 23),
      );
    });

    test('xterm SearchAddon Incremental Find Next', () async {
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

    test('xterm SearchAddon Incremental Find Previous', () async {
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

    test('xterm SearchAddon Simple Regex', () async {
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

    test('xterm SearchAddon single result remains selected', () async {
      await terminal.writeAndWait('abc def');
      expect(search.findNext('abc'), isTrue);
      expect(search.findNext('abc'), isTrue);
      expect(terminal.getSelection(), 'abc');
    });

    test('xterm SearchAddon wide unicode bounds', () async {
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

    test('should split highlight decorations for a wrapped match', () async {
      terminal.resize(10, 5);
      await terminal.writeAndWait('0123456789abcde');
      expect(
        search.findNext(
          '9abc',
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      final inactive = terminal.decorations
          .where((value) => value.layer == TerminalDecorationLayer.bottom)
          .toList();
      expect(inactive, hasLength(2));
      expect((inactive[0].x, inactive[0].width), (9, 1));
      expect((inactive[1].x, inactive[1].width), (0, 3));
      expect(
        inactive.where((value) => value.overviewRulerColor != null),
        hasLength(2),
      );
    });

    test('should only add one overview ruler marker per buffer line', () async {
      terminal.resize(10, 5);
      await terminal.writeAndWait('abcdefghij');
      expect(
        search.findNext(
          '[af]',
          options: const TerminalSearchOptions(
            regex: true,
            decorations: _decorations,
          ),
        ),
        isTrue,
      );
      final inactive = terminal.decorations.where(
        (value) => value.layer == TerminalDecorationLayer.bottom,
      );
      expect(
        inactive.where((value) => value.overviewRulerColor != null),
        hasLength(1),
      );
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

    test('xterm SearchAddon forward result values', () async {
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
              value.overviewRulerColor == null,
        ),
        isTrue,
      );
      expect(
        terminal.decorations
            .where(
              (value) =>
                  value.layer == TerminalDecorationLayer.bottom &&
                  value.overviewRulerColor == '#ffff00',
            )
            .length,
        1,
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

    test('xterm SearchAddon forward results require decorations', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('abc');
      expect(search.findNext('a'), isTrue);
      expect(events, isEmpty);
      expect(
        search.findNext(
          'b',
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      expect(_resultTuples(events), <(int, int)>[(1, 0)]);
    });

    test('xterm SearchAddon reverse results require decorations', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('abc');
      expect(search.findPrevious('a'), isTrue);
      expect(events, isEmpty);
      expect(
        search.findPrevious(
          'b',
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      expect(_resultTuples(events), <(int, int)>[(1, 0)]);
    });

    test('xterm SearchAddon reverse result values', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('abc bc c');
      const options = TerminalSearchOptions(decorations: _decorations);
      expect(search.findPrevious('a', options: options), isTrue);
      terminal.clearSelection();
      expect(search.findPrevious('b', options: options), isTrue);
      expect(search.findPrevious('d', options: options), isFalse);
      expect(search.findPrevious('c', options: options), isTrue);
      expect(search.findPrevious('c', options: options), isTrue);
      expect(search.findPrevious('c', options: options), isTrue);
      expect(
        _resultTuples(events),
        <(int, int)>[
          (1, 0),
          (2, 1),
          (0, -1),
          (3, 2),
          (3, 1),
          (3, 0),
        ],
      );
    });

    test('xterm SearchAddon forward incremental results', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('d abc aabc d');
      const options = TerminalSearchOptions(
        incremental: true,
        decorations: _decorations,
      );
      for (final term in <String>['a', 'ab', 'abc', 'abc', 'd', 'abcd']) {
        search.findNext(term, options: options);
      }
      expect(
        _resultTuples(events),
        <(int, int)>[
          (3, 0),
          (2, 0),
          (2, 0),
          (2, 1),
          (2, 1),
          (0, -1),
        ],
      );
    });

    test('xterm SearchAddon reverse incremental results', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('d abc aabc d');
      const options = TerminalSearchOptions(
        incremental: true,
        decorations: _decorations,
      );
      for (final term in <String>['a', 'ab', 'abc', 'abc', 'd', 'abcd']) {
        search.findPrevious(term, options: options);
      }
      expect(
        _resultTuples(events),
        <(int, int)>[
          (3, 2),
          (2, 1),
          (2, 1),
          (2, 0),
          (2, 1),
          (0, -1),
        ],
      );
    });

    test('xterm SearchAddon forward result limit', () async {
      search.dispose();
      search = SearchAddon();
      terminal.loadAddon(search);
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      final line = '${'a bc' * 10}\r\n';
      await terminal.writeAndWait(line * 150);
      const options = TerminalSearchOptions(decorations: _decorations);
      expect(search.findNext('a', options: options), isTrue);
      expect(search.findNext('a', options: options), isTrue);
      expect(search.findNext('bc', options: options), isTrue);
      expect(
        _resultTuples(events),
        <(int, int)>[(1000, 0), (1000, 1), (1000, 1)],
      );
    });

    test('xterm SearchAddon reverse result limit', () async {
      search.dispose();
      search = SearchAddon();
      terminal.loadAddon(search);
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      final line = '${'a bc' * 10}\r\n';
      await terminal.writeAndWait(line * 150);
      const options = TerminalSearchOptions(decorations: _decorations);
      expect(search.findPrevious('a', options: options), isTrue);
      expect(search.findPrevious('a', options: options), isTrue);
      expect(search.findPrevious('bc', options: options), isTrue);
      expect(
        _resultTuples(events),
        <(int, int)>[(1000, -1), (1000, -1), (1000, -1)],
      );
    });

    test('xterm SearchAddon forward refresh after write', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('abc bc c\r\n' * 2);
      const options = TerminalSearchOptions(decorations: _decorations);
      expect(search.findNext('abc', options: options), isTrue);
      await terminal.writeAndWait('abc bc c\r\n');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(_resultTuples(events), <(int, int)>[(2, 0), (3, 0)]);
    });

    test('xterm SearchAddon reverse refresh after write', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('abc bc c\r\n' * 2);
      const options = TerminalSearchOptions(decorations: _decorations);
      expect(search.findPrevious('abc', options: options), isTrue);
      await terminal.writeAndWait('abc bc c\r\n');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(_resultTuples(events), <(int, int)>[(2, 1), (3, 1)]);
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

    test('xterm SearchAddon before and after findNext', () async {
      final events = _searchEvents(search);
      await terminal.writeAndWait('abc');
      search.findNext('a');
      expect(events, <String>['before', 'after']);
    });

    test('xterm SearchAddon before and after findPrevious', () async {
      final events = _searchEvents(search);
      await terminal.writeAndWait('abc');
      search.findPrevious('a');
      expect(events, <String>['before', 'after']);
    });

    test('xterm SearchAddon events for each call', () async {
      final events = _searchEvents(search);
      await terminal.writeAndWait('abc abc');
      search
        ..findNext('abc')
        ..findNext('abc');
      expect(
        events,
        <String>['before', 'after', 'before', 'after'],
      );
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

    test('xterm SearchAddon wide highlight scan', () async {
      terminal.resize(3, 5);
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('𝄞𝄞𝄞');
      expect(
        search.findNext(
          '𝄞',
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      expect((events.single.resultCount, events.single.resultIndex), (3, 0));
    });

    test('xterm SearchAddon issue 2444 forward', () async {
      await terminal.writeAndWait(await _issue2444Fixture());
      const expected = <TerminalBufferPosition>[
        TerminalBufferPosition(24, 53),
        TerminalBufferPosition(24, 76),
        TerminalBufferPosition(24, 96),
        TerminalBufferPosition(1, 114),
        TerminalBufferPosition(11, 115),
        TerminalBufferPosition(1, 126),
        TerminalBufferPosition(11, 127),
        TerminalBufferPosition(1, 135),
        TerminalBufferPosition(11, 136),
        TerminalBufferPosition(24, 53),
      ];
      for (final position in expected) {
        expect(search.findNext('opencv'), isTrue);
        expect(terminal.getSelectionPosition()!.start, position);
      }
    });

    test('xterm SearchAddon issue 2444 reverse', () async {
      await terminal.writeAndWait(await _issue2444Fixture());
      const expected = <TerminalBufferPosition>[
        TerminalBufferPosition(11, 136),
        TerminalBufferPosition(1, 135),
        TerminalBufferPosition(11, 127),
        TerminalBufferPosition(1, 126),
        TerminalBufferPosition(11, 115),
        TerminalBufferPosition(1, 114),
        TerminalBufferPosition(24, 96),
        TerminalBufferPosition(24, 76),
        TerminalBufferPosition(24, 53),
        TerminalBufferPosition(11, 136),
      ];
      for (final position in expected) {
        expect(search.findPrevious('opencv'), isTrue);
        expect(terminal.getSelectionPosition()!.start, position);
      }
    });

    test('xterm SearchAddon null cells before matches', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      await terminal.writeAndWait('\u001b[CHi Hi');
      expect(
        search.findPrevious(
          'h',
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      expect((events.single.resultCount, events.single.resultIndex), (2, 1));
    });

    test('xterm SearchAddon wrapped match count', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      final content = 'a' * 300;
      await terminal.writeAndWait(content);
      expect(
        search.findNext(
          content,
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      expect((events.single.resultCount, events.single.resultIndex), (1, 0));
    });

    test('xterm SearchAddon wrapped reverse search', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      final content = 'x' * 300;
      await terminal.writeAndWait(content);
      expect(
        search.findPrevious(
          content,
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      expect((events.single.resultCount, events.single.resultIndex), (1, 0));
    });

    test('xterm SearchAddon wrapped count refresh', () async {
      final events = <TerminalSearchResult>[];
      search.onDidChangeResults.listen(events.add);
      final content = 'z' * 300;
      await terminal.writeAndWait(content);
      expect(
        search.findNext(
          content,
          options: const TerminalSearchOptions(decorations: _decorations),
        ),
        isTrue,
      );
      await terminal.writeAndWait('\r\n$content');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
        events.map((event) => event.resultCount),
        <int>[1, 2],
      );
    });
  });
}

Future<String> _issue2444Fixture() async {
  var fixture = await File(
    'packages/termworld/test/fixtures/xterm/issue-2444',
  ).readAsString();
  if (!Platform.isWindows) fixture = fixture.replaceAll('\n', '\n\r');
  return fixture;
}

List<String> _searchEvents(SearchAddon search) {
  final events = <String>[];
  search.onBeforeSearch.listen((_) => events.add('before'));
  search.onAfterSearch.listen((_) => events.add('after'));
  return events;
}

List<(int, int)> _resultTuples(List<TerminalSearchResult> events) => events
    .map((event) => (event.resultCount, event.resultIndex))
    .toList(growable: false);

String _selectedSuffix(Terminal terminal, int trailingLength) {
  final selection = terminal.getSelectionPosition()!;
  final line = terminal.buffer.active
      .getLine(selection.start.y)!
      .translateToString(trimRight: true);
  final end = (selection.end.x + trailingLength).clamp(0, line.length);
  return line.substring(selection.start.x, end);
}
