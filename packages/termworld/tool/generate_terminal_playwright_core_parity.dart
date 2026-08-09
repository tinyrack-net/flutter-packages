import 'dart:convert';
import 'dart:io';

void main() {
  final package = Directory.current.path.endsWith('packages/termworld')
      ? Directory.current
      : Directory('packages/termworld');
  final sourceFile = File(
    '${package.path}/test/upstream_headless_terminal_parity_test.dart',
  );
  final outputFile = File(
    '${package.path}/test/upstream_terminal_playwright_core_parity_test.dart',
  );
  var source = sourceFile.readAsStringSync();
  for (final entry in _names.entries) {
    final oldName =
        'xterm HeadlessTerminal ${entry.key.toString().padLeft(2, '0')}';
    source = source.replaceFirst("test('$oldName'", "test('${entry.value}'");
  }
  outputFile.writeAsStringSync(source);

  final referenceFile = File('${package.path}/tool/xterm_reference.json');
  final mappingsFile = File(
    '${package.path}/tool/xterm_parity_mappings.json',
  );
  final reference =
      jsonDecode(referenceFile.readAsStringSync()) as Map<String, Object?>;
  final mappings =
      jsonDecode(mappingsFile.readAsStringSync()) as Map<String, Object?>;
  final mappedTests = mappings['tests']! as Map<String, Object?>;
  final wanted = <String>{..._names.values, ..._viewNames};
  final additions = StringBuffer();
  for (final test
      in (reference['tests']! as List<Object?>).cast<Map<String, Object?>>()) {
    if (test['file'] != 'test/playwright/Terminal.test.ts' ||
        !wanted.contains(test['name'])) {
      continue;
    }
    final id = test['id']! as String;
    final name = test['name']! as String;
    if (mappedTests.containsKey(id)) continue;
    final target = _viewNames.contains(name)
        ? 'test/upstream_terminal_playwright_view_parity_test.dart'
        : 'test/upstream_terminal_playwright_core_parity_test.dart';
    final kind = _widgetNames.contains(name) ? 'testWidgets' : 'test';
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write('"dartTestFile":${jsonEncode(target)},')
      ..write(
        '"dartTestName":${jsonEncode(name)},'
        '"dartTestKind":"$kind"},\n',
      );
  }
  const marker = '  "tests": {\n';
  var updated = mappingsFile.readAsStringSync();
  for (final name in _widgetNames) {
    final testName = jsonEncode(name);
    updated = updated.replaceFirst(
      '"dartTestFile":'
          '"test/upstream_terminal_playwright_view_parity_test.dart",'
          '"dartTestName":$testName,"dartTestKind":"test"',
      '"dartTestFile":'
          '"test/upstream_terminal_playwright_view_parity_test.dart",'
          '"dartTestName":$testName,"dartTestKind":"testWidgets"',
    );
  }
  if (additions.isEmpty) {
    mappingsFile.writeAsStringSync(updated);
    return;
  }
  if (!updated.contains(marker)) {
    throw StateError('tests mapping marker is missing');
  }
  mappingsFile.writeAsStringSync(
    updated.replaceFirst(marker, '$marker$additions'),
  );
}

const _names = <int, String>{
  0: 'Default options',
  1: 'write',
  2: 'write with callback',
  3: 'write - bytes (UTF8)',
  4: 'write - bytes (UTF8) with callback',
  5: 'writeln',
  6: 'writeln with callback',
  7: 'writeln - bytes (UTF8)',
  8: 'clear',
  9: 'clearMarkers',
  10: 'getter',
  11: 'setter',
  12: 'constructor',
  13: 'dispose (addon)',
  14: 'dispose (terminal)',
  15: 'onCursorMove',
  16: 'onData',
  17: 'onLineFeed',
  18: 'onRender',
  19: 'onScroll',
  20: 'onResize',
  21: 'onTitleChange',
  22: 'onBell',
  23: 'Proposed API check',
  24: 'defaults',
  25: 'applicationCursorKeysMode',
  26: 'applicationKeypadMode',
  27: 'bracketedPasteMode',
  28: 'insertMode',
  29: 'mouseTrackingMode',
  30: 'originMode',
  31: 'reverseWraparoundMode',
  32: 'sendFocusMode',
  33: 'wraparoundMode',
  34: 'dispose',
  35: 'cursorX, cursorY',
  36: 'viewportY',
  37: 'baseY',
  38: 'length',
  39: 'invalid index',
  40: 'isWrapped',
  41: 'translateToString',
  42: 'getCell',
  43: 'active, normal, alternate',
};

const _viewNames = <String>{
  'onKey',
  'resize during write should not throw',
  'object.keys return the correct number of options',
  'paste',
  'selection',
  'should fire for programmatic selection changes',
  'foreground',
  'background',
  'focus, blur',
  'dispose (opened)',
  'render when visible after hidden',
  'should register decorations and render them when terminal open is called',
  'should return undefined when the marker has already been disposed of',
  'should throw when a negative x offset is provided',
  'should not add an overview ruler when width is not set',
  'should add an overview ruler when width is set',
  'should fire provideLinks when hovering cells',
  'should fire hover and leave events on the link',
  'should work fine when hover and leave callbacks are not provided',
  'should fire activate events when clicking the link',
  'should work when multiple links are provided on the same line',
  'should dispose links when hovering away',
  'should fire on mousedown when clearing selection',
  'should not fire on mousedown when no prior selection',
  'should fire once on mousedown to clear, and again on mouseup after drag',
};

const _widgetNames = <String>{
  'focus, blur',
  'dispose (opened)',
  'render when visible after hidden',
  'should register decorations and render them when terminal open is called',
  'should return undefined when the marker has already been disposed of',
  'should throw when a negative x offset is provided',
  'should not add an overview ruler when width is not set',
  'should add an overview ruler when width is set',
  'should fire provideLinks when hovering cells',
  'should fire hover and leave events on the link',
  'should work fine when hover and leave callbacks are not provided',
  'should fire activate events when clicking the link',
  'should work when multiple links are provided on the same line',
  'should dispose links when hovering away',
  'should fire on mousedown when clearing selection',
  'should not fire on mousedown when no prior selection',
  'should fire once on mousedown to clear, and again on mouseup after drag',
};
