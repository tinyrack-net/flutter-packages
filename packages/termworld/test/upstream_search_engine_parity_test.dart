import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/search_engine.dart';
import 'package:termworld/src/addons/search_line_cache.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('xterm SearchEngine 00', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.find('', 0, 0), isNull);
  });
  test('xterm SearchEngine 01', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    _expectResult(h.engine.find('World', 0, 0), 'World', 6, 0, 5);
  });
  test('xterm SearchEngine 02', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello Hello Hello');
    _expectResult(h.engine.find('Hello', 0, 7), 'Hello', 12, 0, 5);
  });
  test('xterm SearchEngine 03', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Line 1\r\nLine 2 target\r\nLine 3');
    _expectResult(h.engine.find('target', 0, 0), 'target', 7, 1, 6);
  });
  test('xterm SearchEngine 04', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.find('NotFound', 0, 0), isNull);
  });
  test('xterm SearchEngine 05', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(
      () => h.engine.find('Hello', 0, 100),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Invalid col: 100 to search in terminal of 80 cols'),
        ),
      ),
    );
  });
  test('xterm SearchEngine 06', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.find('Hello', 0, 79), isNull);
  });
  test('xterm SearchEngine 07', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.find('llo', 0, 3), isNull);
  });
  test('xterm SearchEngine 08', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello WORLD');
    _expectResult(h.engine.find('world', 0, 0), 'world', 6, 0, 5);
  });
  test('xterm SearchEngine 09', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello WORLD');
    _expectResult(
      h.engine.find(
        'WORLD',
        0,
        0,
        options: const SearchEngineOptions(caseSensitive: true),
      ),
      'WORLD',
      6,
      0,
      5,
    );
  });
  test('xterm SearchEngine 10', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello WORLD');
    expect(
      h.engine.find(
        'world',
        0,
        0,
        options: const SearchEngineOptions(caseSensitive: true),
      ),
      isNull,
    );
  });
  test('xterm SearchEngine 11', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello world wonderful');
    _expectResult(_whole(h, 'world'), 'world', 6, 0, 5);
  });
  test('xterm SearchEngine 12', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello wonderful');
    expect(_whole(h, 'world'), isNull);
  });
  test('xterm SearchEngine 13', () async {
    final h = _harness();
    await h.terminal.writeAndWait('world is great');
    _expectResult(_whole(h, 'world'), 'world', 0, 0, 5);
  });
  test('xterm SearchEngine 14', () async {
    final h = _harness();
    await h.terminal.writeAndWait('hello world');
    _expectResult(_whole(h, 'world'), 'world', 6, 0, 5);
  });
  test('xterm SearchEngine 15', () async {
    final h = _harness();
    await h.terminal.writeAndWait('hello,world!test');
    _expectResult(_whole(h, 'world'), 'world', 6, 0, 5);
  });
  test('xterm SearchEngine 16', () async {
    final h = _harness();
    await h.terminal.writeAndWait('helloworld');
    expect(_whole(h, 'world'), isNull);
  });
  test('xterm SearchEngine 17', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello 123 World');
    _expectResult(_regex(h, '[0-9]+'), '123', 6, 0, 3);
  });
  test('xterm SearchEngine 18', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello WORLD');
    _expectResult(_regex(h, 'world'), 'WORLD', 6, 0, 5);
  });
  test('xterm SearchEngine 19', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello WORLD world');
    _expectResult(_regex(h, 'WORLD', sensitive: true), 'WORLD', 6, 0, 5);
  });
  test('xterm SearchEngine 20', () async {
    final h = _harness();
    await h.terminal.writeAndWait(
      'Email: test@example.com and another@domain.org',
    );
    _expectResult(
      _regex(h, r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      'test@example.com',
      7,
      0,
      16,
    );
  });
  test('xterm SearchEngine 21', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(() => _regex(h, '[invalid'), throwsA(isA<FormatException>()));
  });
  test('xterm SearchEngine 22', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(_regex(h, '.*?'), isNull);
  });
  test('xterm SearchEngine 23', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello WORLD world');
    _expectResult(_regex(h, '[A-Z]+', sensitive: true), 'H', 0, 0, 1);
  });
  test('xterm SearchEngine 24', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello WORLD wonderful');
    const options = SearchEngineOptions(
      wholeWord: true,
      caseSensitive: true,
    );
    _expectResult(
      h.engine.find('WORLD', 0, 0, options: options),
      'WORLD',
      6,
      0,
      5,
    );
    expect(h.engine.find('world', 0, 0, options: options), isNull);
  });
  test('xterm SearchEngine 25', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.findNextWithSelection(''), isNull);
  });
  test('xterm SearchEngine 26', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World Hello');
    _expectResult(h.engine.findNextWithSelection('Hello'), 'Hello', 0, 0, 5);
  });
  test('xterm SearchEngine 27', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World Hello Again');
    h.terminal.select(0, 0, 5);
    _expectResult(
      h.engine.findNextWithSelection('Hello', cachedSearchTerm: 'Hello'),
      'Hello',
      12,
      0,
      5,
    );
  });
  test('xterm SearchEngine 28', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World Hello');
    h.terminal.select(12, 0, 5);
    _expectResult(
      h.engine.findNextWithSelection('Hello', cachedSearchTerm: 'Hello'),
      'Hello',
      0,
      0,
      5,
    );
  });
  test('xterm SearchEngine 29', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Line 1 test\r\nLine 2\r\nLine 3 test');
    h.terminal.select(7, 0, 4);
    _expectResult(
      h.engine.findNextWithSelection('test', cachedSearchTerm: 'test'),
      'test',
      7,
      2,
      4,
    );
  });
  test('xterm SearchEngine 30', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    h.terminal.select(0, 0, 5);
    _expectResult(h.engine.findNextWithSelection('Hello'), 'Hello', 0, 0, 5);
  });
  test('xterm SearchEngine 31', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.findNextWithSelection('NotFound'), isNull);
    expect(h.terminal.hasSelection(), isFalse);
  });
  test('xterm SearchEngine 32', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.findPreviousWithSelection(''), isNull);
  });
  test('xterm SearchEngine 33', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World Hello');
    _expectResult(
      h.engine.findPreviousWithSelection('Hello'),
      'Hello',
      12,
      0,
      5,
    );
  });
  test('xterm SearchEngine 34', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World Hello Again');
    h.terminal.select(12, 0, 5);
    final result = h.engine.findPreviousWithSelection('Hello');
    expect(result, isNotNull);
    expect(result!.row, 0);
  });
  test('xterm SearchEngine 35', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World Hello');
    h.terminal.select(0, 0, 5);
    final result = h.engine.findPreviousWithSelection('Hello');
    expect(result, isNotNull);
    expect(result!.row, 0);
  });
  test('xterm SearchEngine 36', () async {
    final h = _harness();
    await h.terminal.writeAndWait('test Line 1\r\nLine 2\r\ntest Line 3');
    h.terminal.select(0, 2, 4);
    final result = h.engine.findPreviousWithSelection('test');
    expect(result, isNotNull);
    expect(result!.column, isA<int>());
  });
  test('xterm SearchEngine 37', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World Hello');
    h.terminal.select(0, 0, 5);
    final result = h.engine.findPreviousWithSelection('Hello');
    expect(result, isNotNull);
    expect(result!.row, 0);
  });
  test('xterm SearchEngine 38', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    expect(h.engine.findPreviousWithSelection('NotFound'), isNull);
    expect(h.terminal.hasSelection(), isFalse);
  });
  test('xterm SearchEngine 39', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello 世界 World');
    _expectResult(h.engine.find('世界', 0, 0), '世界', 6, 0, 4);
  });
  test('xterm SearchEngine 40', () async {
    final h = _harness();
    await h.terminal.writeAndWait('中文测试');
    _expectResult(h.engine.find('测试', 0, 0), '测试', 4, 0, 4);
  });
  test('xterm SearchEngine 41', () async {
    final h = _harness();
    await h.terminal.writeAndWait('${'A' * 100}target${'B' * 50}');
    _expectResult(h.engine.find('target', 0, 0), 'target', 20, 1, 6);
  });
  test('xterm SearchEngine 42', () async {
    final h = _harness();
    await h.terminal.writeAndWait('${'中' * 50}target${'文' * 30}');
    _expectResult(h.engine.find('target', 0, 0), 'target', 20, 1, 6);
  });
  test('xterm SearchEngine 43', () async {
    final h = _harness();
    await h.terminal.writeAndWait('${'A' * 200}\r\nNext line with target');
    _expectResult(h.engine.find('target', 0, 0), 'target', 15, 3, 6);
  });
  test('xterm SearchEngine 44', () {
    final h = _harness();
    expect(h.engine.find('anything', 0, 0), isNull);
  });
  test('xterm SearchEngine 45', () {
    final h = _harness();
    expect(h.engine.find('test', 1000, 0), isNull);
  });
  test('xterm SearchEngine 46', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    _expectResult(h.engine.find('Hello', 0, 0), 'Hello', 0, 0, 5);
  });
  test('xterm SearchEngine 47', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    _expectResult(h.engine.find('Hello', -1, -1), 'Hello', 0, 0, 5);
  });
  test('xterm SearchEngine 48', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    _expectResult(
      h.engine.find('Hello', 0, 0),
      'Hello',
      0,
      0,
      5,
    );
  });
  test('xterm SearchEngine 49', () async {
    final h = _harness();
    await h.terminal.writeAndWait(
      'word1 word2,word3(word4)word5[word6]word7{word8}',
    );
    for (var index = 1; index <= 8; index++) {
      expect(_whole(h, 'word$index'), isNotNull);
    }
  });
  test('xterm SearchEngine 50', () async {
    final h = _harness();
    await h.terminal.writeAndWait('start middle end');
    _expectResult(_whole(h, 'start'), 'start', 0, 0, 5);
    _expectResult(_whole(h, 'middle'), 'middle', 6, 0, 6);
    _expectResult(_whole(h, 'end'), 'end', 13, 0, 3);
  });
  test('xterm SearchEngine 51', () async {
    final h = _harness();
    await h.terminal.writeAndWait('中文 test 测试');
    final result = h.engine.find('test', 0, 0);
    expect(result, isNotNull);
    expect(result!.column, isA<int>());
  });
  test('xterm SearchEngine 52', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    _expectResult(h.engine.find('World', 0, 0), 'World', 6, 0, 5);
  });
  test('xterm SearchEngine 53', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello 世界');
    expect(h.engine.find('世界', 0, 0)!.size, greaterThanOrEqualTo(2));
  });
  test('xterm SearchEngine 54', () async {
    final h = _harness();
    final match = 'A' * 100;
    await h.terminal.writeAndWait(match);
    expect(h.engine.find(match, 0, 0)!.size, greaterThanOrEqualTo(100));
  });
  test('xterm SearchEngine 55', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    h.cache.initLinesCache();
    final first = h.engine.find('World', 0, 0);
    final second = h.engine.find('World', 0, 0);
    expect(first, second);
  });
  test('xterm SearchEngine 56', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Hello World');
    _expectResult(h.engine.find('World', 0, 0), 'World', 6, 0, 5);
  });
  test('xterm SearchEngine 57', () async {
    final h = _harness();
    await h.terminal.writeAndWait('Initial text');
    h.cache.initLinesCache();
    expect(h.engine.find('Initial', 0, 0), isNotNull);
    await h.terminal.writeAndWait('\r\nNew line');
    _expectResult(h.engine.find('New', 0, 0), 'New', 0, 1, 3);
  });
}

({Terminal terminal, SearchLineCache cache, SearchEngine engine}) _harness() {
  final terminal = Terminal();
  final cache = SearchLineCache(terminal);
  addTearDown(cache.dispose);
  addTearDown(terminal.dispose);
  return (
    terminal: terminal,
    cache: cache,
    engine: SearchEngine(terminal, cache),
  );
}

SearchEngineResult? _whole(
  ({Terminal terminal, SearchLineCache cache, SearchEngine engine}) harness,
  String term,
) => harness.engine.find(
  term,
  0,
  0,
  options: const SearchEngineOptions(wholeWord: true),
);

SearchEngineResult? _regex(
  ({Terminal terminal, SearchLineCache cache, SearchEngine engine}) harness,
  String term, {
  bool sensitive = false,
}) => harness.engine.find(
  term,
  0,
  0,
  options: SearchEngineOptions(regex: true, caseSensitive: sensitive),
);

void _expectResult(
  SearchEngineResult? result,
  String term,
  int column,
  int row,
  int size,
) {
  expect(
    result,
    SearchEngineResult(term: term, column: column, row: row, size: size),
  );
}
