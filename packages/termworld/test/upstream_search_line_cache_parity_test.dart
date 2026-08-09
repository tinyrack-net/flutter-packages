import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/search_line_cache.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  test('xterm SearchLineCache 00', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    expect(cache, isA<SearchLineCache>());
  });

  test('xterm SearchLineCache 01', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 02', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache.initLinesCache();
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 03', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache
      ..initLinesCache()
      ..setLineInCache(0, const SearchLineCacheEntry('test', <int>[0]))
      ..initLinesCache();
    _expectEntry(cache.getLineFromCache(0), 'test', <int>[0]);
  });

  test('xterm SearchLineCache 04', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache
      ..initLinesCache()
      ..setLineInCache(0, const SearchLineCacheEntry('test', <int>[0]));
    _expectEntry(cache.getLineFromCache(0), 'test', <int>[0]);
  });

  test('xterm SearchLineCache 05', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    expect(cache.getLineFromCache(0), isNull);
    expect(cache.getLineFromCache(10), isNull);
  });

  test('xterm SearchLineCache 06', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache.initLinesCache();
    expect(cache.getLineFromCache(0), isNull);
    expect(cache.getLineFromCache(50), isNull);
  });

  test('xterm SearchLineCache 07', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache
      ..initLinesCache()
      ..setLineInCache(
        5,
        const SearchLineCacheEntry('test content', <int>[0]),
      );
    _expectEntry(cache.getLineFromCache(5), 'test content', <int>[0]);
  });

  test('xterm SearchLineCache 08', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache.setLineInCache(
      0,
      const SearchLineCacheEntry('test content', <int>[0]),
    );
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 09', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache
      ..initLinesCache()
      ..setLineInCache(
        10,
        const SearchLineCacheEntry('test content', <int>[0]),
      );
    _expectEntry(cache.getLineFromCache(10), 'test content', <int>[0]);
  });

  test('xterm SearchLineCache 10', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache
      ..initLinesCache()
      ..setLineInCache(0, const SearchLineCacheEntry('first', <int>[0]))
      ..setLineInCache(0, const SearchLineCacheEntry('second', <int>[0]));
    _expectEntry(cache.getLineFromCache(0), 'second', <int>[0]);
  });

  test('xterm SearchLineCache 11', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('Hello World');
    _expectEntry(
      cache.translateBufferLineToStringWithWrap(0, trimRight: true),
      'Hello World',
      <int>[0],
    );
  });

  test('xterm SearchLineCache 12', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('Hello World   ');
    final trimmed = cache.translateBufferLineToStringWithWrap(
      0,
      trimRight: true,
    );
    final untrimmed = cache.translateBufferLineToStringWithWrap(
      0,
      trimRight: false,
    );
    expect(trimmed.line.trimRight(), 'Hello World');
    expect(untrimmed.line, startsWith('Hello World   '));
    expect(untrimmed.line.length, greaterThan(trimmed.line.length));
  });

  test('xterm SearchLineCache 13', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    final text = 'A' * 200;
    await terminal.writeAndWait(text);
    final entry = cache.translateBufferLineToStringWithWrap(
      0,
      trimRight: true,
    );
    expect(entry.line, text);
    expect(entry.lineOffsets.length, greaterThan(1));
    expect(entry.lineOffsets.first, 0);
  });

  test('xterm SearchLineCache 14', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('Hello 世界');
    _expectEntry(
      cache.translateBufferLineToStringWithWrap(0, trimRight: true),
      'Hello 世界',
      <int>[0],
    );
  });

  test('xterm SearchLineCache 15', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    _expectEntry(
      cache.translateBufferLineToStringWithWrap(0, trimRight: true),
      '',
      <int>[0],
    );
  });

  test('xterm SearchLineCache 16', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    _expectEntry(
      cache.translateBufferLineToStringWithWrap(1000, trimRight: true),
      '',
      <int>[0],
    );
  });

  test('xterm SearchLineCache 17', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    await terminal.writeAndWait(
      'Line 1\r\nLine 2 with some longer content that might wrap\r\nLine 3',
    );
    expect(
      cache.translateBufferLineToStringWithWrap(0, trimRight: true).line,
      'Line 1',
    );
    expect(
      cache.translateBufferLineToStringWithWrap(1, trimRight: true).line,
      'Line 2 with some longer content that might wrap',
    );
    expect(
      cache.translateBufferLineToStringWithWrap(2, trimRight: true).line,
      'Line 3',
    );
  });

  test('xterm SearchLineCache 18', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    _seed(cache);
    await terminal.writeAndWait('test\r\n');
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 19', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    _seed(cache);
    await terminal.writeAndWait('some text');
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 20', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    _seed(cache);
    terminal.resize(100, 30);
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 21', () {
    final (:cache, :terminal) = _harness();
    addTearDown(terminal.dispose);
    _seed(cache);
    cache.dispose();
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 22', () {
    final (:cache, :terminal) = _harness();
    addTearDown(terminal.dispose);
    cache
      ..initLinesCache()
      ..dispose()
      ..dispose();
    expect(cache.getLineFromCache(0), isNull);
  });

  test('xterm SearchLineCache 23', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    const line =
        'A very long line that wraps multiple times across several '
        'terminal lines';
    cache
      ..initLinesCache()
      ..setLineInCache(
        0,
        const SearchLineCacheEntry(line, <int>[0, 20, 40, 60]),
      );
    _expectEntry(cache.getLineFromCache(0), line, <int>[0, 20, 40, 60]);
    expect(cache.getLineFromCache(0)!.line.length, 72);
  });

  test('xterm SearchLineCache 24', () {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    cache
      ..initLinesCache()
      ..setLineInCache(
        0,
        const SearchLineCacheEntry('Hello 世界 🌍 测试', <int>[0]),
      );
    _expectEntry(cache.getLineFromCache(0), 'Hello 世界 🌍 测试', <int>[0]);
  });

  test('xterm SearchLineCache 25', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('Hello World');
    expect(
      cache.translateBufferLineToStringWithWrap(0, trimRight: true).line,
      terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
    );
  });

  test('xterm SearchLineCache 26', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    const content =
        'This is a very long line that will definitely wrap around '
        'in an 80 column terminal and should be handled correctly by the cache';
    await terminal.writeAndWait(content);
    final entry = cache.translateBufferLineToStringWithWrap(
      0,
      trimRight: true,
    );
    expect(entry.line, content);
    expect(entry.lineOffsets.length, greaterThan(1));
  });

  test('xterm SearchLineCache 27', () async {
    final (:cache, :terminal) = _harness();
    addTearDown(cache.dispose);
    addTearDown(terminal.dispose);
    await terminal.writeAndWait('Before\u001b[31mRed Text\u001b[0mAfter');
    final line = cache
        .translateBufferLineToStringWithWrap(0, trimRight: true)
        .line;
    expect(line, contains('Before'));
    expect(line, contains('Red Text'));
    expect(line, contains('After'));
  });
}

({SearchLineCache cache, Terminal terminal}) _harness() {
  final terminal = Terminal();
  return (cache: SearchLineCache(terminal), terminal: terminal);
}

void _seed(SearchLineCache cache) {
  cache
    ..initLinesCache()
    ..setLineInCache(0, const SearchLineCacheEntry('test', <int>[0]));
  _expectEntry(cache.getLineFromCache(0), 'test', <int>[0]);
}

void _expectEntry(
  SearchLineCacheEntry? entry,
  String line,
  List<int> offsets,
) {
  expect(entry, isNotNull);
  expect(entry!.line, line);
  expect(entry.lineOffsets, offsets);
}
