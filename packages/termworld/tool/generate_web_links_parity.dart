import 'dart:convert';
import 'dart:io';

void main() {
  final package = Directory.current.path.endsWith('packages/termworld')
      ? Directory.current
      : Directory('packages/termworld');
  final referenceFile = File('${package.path}/tool/xterm_reference.json');
  final mappingsFile = File(
    '${package.path}/tool/xterm_parity_mappings.json',
  );
  final reference =
      jsonDecode(referenceFile.readAsStringSync()) as Map<String, Object?>;
  final mappings =
      jsonDecode(mappingsFile.readAsStringSync()) as Map<String, Object?>;
  final mappedTests = mappings['tests']! as Map<String, Object?>;
  final cases =
      (reference['tests']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .where(
            (entry) =>
                entry['file'] ==
                'addons/addon-web-links/test/WebLinksAddon.test.ts',
          )
          .toList()
        ..sort(
          (left, right) => (left['name']! as String).compareTo(
            right['name']! as String,
          ),
        );

  final source = StringBuffer(_header);
  for (final entry in cases) {
    final name = entry['name']! as String;
    final escapedName = _dartString(name);
    if (name.startsWith('.')) {
      final host = name == '.com' ? 'foo.com' : 'foo$name';
      source.writeln(
        "    test('$escapedName', () => _verifyHost('$host'));",
      );
    } else {
      source.writeln(
        "    test('$escapedName', ${_helperFor(name)});",
      );
    }
  }
  source.write(_footer);
  File(
    '${package.path}/test/upstream_web_links_addon_parity_test.dart',
  ).writeAsStringSync(source.toString());

  final additions = StringBuffer();
  for (final entry in cases) {
    final id = entry['id']! as String;
    if (mappedTests.containsKey(id)) continue;
    final name = entry['name']! as String;
    additions
      ..write('    ${jsonEncode(id)}: {')
      ..write(
        '"dartTestFile":"test/upstream_web_links_addon_parity_test.dart",',
      )
      ..write('"dartTestName":${jsonEncode(name)},"dartTestKind":"test"},\n');
  }
  if (additions.isNotEmpty) {
    const marker = '  "tests": {\n';
    final original = mappingsFile.readAsStringSync();
    if (!original.contains(marker)) {
      throw StateError('tests mapping marker is missing');
    }
    mappingsFile.writeAsStringSync(
      original.replaceFirst(marker, '$marker$additions'),
    );
  }
}

String _helperFor(String name) => switch (name) {
  'all half width' => '_verifyAllHalfWidth',
  'url after full width' => '_verifyUrlAfterFullWidth',
  'full width within url and before' => '_verifyFullWidthWithinUrl',
  'name + password url after full width and combining' =>
    '_verifyCredentialsAfterCombining',
  'url encoded params work properly' => '_verifyEncodedParams',
  'uppercase in protocol and host, default ports' => '_verifyUppercase',
  _ => throw StateError('Unknown WebLinksAddon case: $name'),
};

String _dartString(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');

const _header = '''
import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_web_links.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  group('WebLinksAddon pinned upstream corpus', () {
''';

const _footer = r'''
  });
}

Future<void> _verifyHost(String host) async {
  final fixture = await _fixture(
    '  http://$host  \r\n'
    '  http://$host/a~b#c~d?e~f  \r\n'
    '  http://$host/colon:test  \r\n'
    '  http://$host/colon:test:  \r\n'
    '"http://$host/"\r\n'
    "'http://$host/'\r\n"
    'http://$host/subpath/+/id',
  );
  try {
    final expected = <String>[
      'http://$host',
      'http://$host/a~b#c~d?e~f',
      'http://$host/colon:test',
      'http://$host/colon:test',
      'http://$host/',
      'http://$host/',
      'http://$host/subpath/+/id',
    ];
    for (var row = 1; row <= expected.length; row++) {
      final links = await fixture.provider.provideLinks(row);
      expect(links.map((link) => link.text), contains(expected[row - 1]));
    }
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyAllHalfWidth() async {
  final fixture = await _fixture(
    'aaa http://example.com aaa http://example.com aaa',
  );
  try {
    final links = await fixture.provider.provideLinks(1);
    expect(links, hasLength(2));
    expect(links[0].text, 'http://example.com');
    expect(links[0].range, _range(5, 1, 22, 1));
    expect(links[1].range, _range(28, 1, 5, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyUrlAfterFullWidth() async {
  final fixture = await _fixture(
    '￥￥￥ http://example.com ￥￥￥ http://example.com aaa',
  );
  try {
    final links = await fixture.provider.provideLinks(1);
    expect(links, hasLength(2));
    expect(links[0].range, _range(8, 1, 25, 1));
    expect(links[1].range, _range(34, 1, 11, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyFullWidthWithinUrl() async {
  const uri = 'https://ko.wikipedia.org/wiki/위키백과:대문';
  final fixture = await _fixture('￥￥￥ $uri aaa $uri ￥￥￥');
  try {
    final links = await fixture.provider.provideLinks(1);
    expect(links, hasLength(2));
    expect(links[0].text, uri);
    expect(links[0].range, _range(8, 1, 11, 2));
    final wrappedLinks = await fixture.provider.provideLinks(2);
    expect(wrappedLinks, hasLength(2));
    expect(wrappedLinks[1].text, uri);
    expect(wrappedLinks[1].range, _range(17, 2, 19, 3));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyCredentialsAfterCombining() async {
  const uri = 'http://test:password@example.com/some_path';
  final fixture = await _fixture('￥￥￥cafe\u0301 $uri');
  try {
    final link = (await fixture.provider.provideLinks(1)).single;
    expect(link.text, uri);
    expect(link.range, _range(12, 1, 13, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyEncodedParams() async {
  const uri = 'http://test:password@example.com/some_path?param=1%202%3';
  final fixture = await _fixture('￥￥￥cafe\u0301 $uri');
  try {
    final link = (await fixture.provider.provideLinks(1)).single;
    expect(link.text, uri);
    expect(link.range, _range(12, 1, 27, 2));
  } finally {
    fixture.dispose();
  }
}

Future<void> _verifyUppercase() async {
  const expected = <String>[
    'HTTP://EXAMPLE.COM',
    'HTTPS://Example.com',
    'HTTP://Example.com:80',
    'HTTP://Example.com:80/staysUpper',
    'HTTP://Ab:xY@abc.com:80/staysUpper',
  ];
  final fixture = await _fixture('${expected.join('  \r\n  ')}  ');
  try {
    for (var row = 1; row <= expected.length; row++) {
      final links = await fixture.provider.provideLinks(row);
      expect(links.map((link) => link.text), contains(expected[row - 1]));
    }
  } finally {
    fixture.dispose();
  }
}

Future<({Terminal terminal, TerminalLinkProvider provider, void Function() dispose})>
_fixture(String text) async {
  final terminal = Terminal(options: TerminalOptions(cols: 40, rows: 10));
  final addon = WebLinksAddon(handler: (_, _) {});
  terminal.loadAddon(addon);
  await terminal.writeAndWait(text);
  return (
    terminal: terminal,
    provider: terminal.linkProviders.last,
    dispose: () {
      addon.dispose();
      terminal.dispose();
    },
  );
}

TerminalBufferRange _range(int startX, int startY, int endX, int endY) =>
    TerminalBufferRange(
      start: TerminalBufferPosition(startX, startY),
      end: TerminalBufferPosition(endX, endY),
    );
''';
