import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_image.dart';

void main() {
  test('xterm IIPHeaderParser 00', () {
    for (final example in _cases) {
      final parser = IipHeaderParser();
      final input = _codePoints(example.source);
      expect(parser.parse(input, 0, input.length), input.length);
      expect(parser.state, IipHeaderState.end);
      expect(parser.fields, example.fields);
    }
  });
  test('xterm IIPHeaderParser 01', () {
    for (final example in _cases) {
      final parser = IipHeaderParser();
      final input = _codePoints(example.source);
      var position = 0;
      var result = -2;
      while (result == -2 && position < input.length) {
        result = parser.parse(
          Uint32List.fromList(<int>[input[position++]]),
          0,
          1,
        );
      }
      expect(result, 1);
      expect(parser.state, IipHeaderState.end);
      expect(parser.fields, example.fields);
    }
  });
  test('xterm IIPHeaderParser 02', () {
    final parser = IipHeaderParser();
    final invalid = _codePoints('size=123456;name=dGVzdA==:');
    expect(parser.parse(invalid, 0, invalid.length), -1);
    _expectFirstCaseAfterReset(parser);
  });
  test('xterm IIPHeaderParser 03', () {
    final parser = IipHeaderParser();
    final invalid = _codePoints('File=size=123456;=dGVzdA==:');
    expect(parser.parse(invalid, 0, invalid.length), -1);
    _expectFirstCaseAfterReset(parser);
  });
  test('xterm IIPHeaderParser 04', () {
    final parser = IipHeaderParser();
    final input = _codePoints('File=size=;name=dGVzdA==:');
    expect(parser.parse(input, 0, input.length), input.length);
    expect(parser.state, IipHeaderState.end);
    expect(parser.fields, <String, Object?>{
      'type': IipSequenceType.file,
      'name': 'test',
      'size': 0,
    });
    _expectFirstCaseAfterReset(parser);
  });
  test('xterm IIPHeaderParser 05', () {
    final parser = IipHeaderParser();
    final input = _codePoints('File=size=123456;name=:');
    expect(parser.parse(input, 0, input.length), input.length);
    expect(parser.state, IipHeaderState.end);
    expect(parser.fields, <String, Object?>{
      'type': IipSequenceType.file,
      'name': '',
      'size': 123456,
    });
    _expectFirstCaseAfterReset(parser);
  });
  test('xterm IIPHeaderParser 06', () {
    final parser = IipHeaderParser();
    final input = _codePoints(
      'File=inline=1;width=;height=20%;preserveAspectRatio=1;'
      'size=123456;name=w7xtbMOkdXTDnw:',
    );
    expect(parser.parse(input, 0, input.length), -1);
    _expectFirstCaseAfterReset(parser);
  });
  test('xterm IIPHeaderParser 07', () {
    final parser = IipHeaderParser();
    final input = _codePoints('FilePart=w7xtbMOkdXTDnw');
    expect(parser.parse(input, 0, input.length), 9);
    expect(parser.state, IipHeaderState.end);
    expect(parser.fields['type'], IipSequenceType.filePart);
  });
  test('xterm IIPHeaderParser 08', () {
    final parser = IipHeaderParser();
    final input = _codePoints('FilePart=w7xtbMOkdXTDnw');
    expect(_parseBytewise(parser, input), 1);
    expect(parser.state, IipHeaderState.end);
    expect(parser.fields['type'], IipSequenceType.filePart);
  });
  test('xterm IIPHeaderParser 09', () {
    _expectMultipart(bytewise: false);
  });
  test('xterm IIPHeaderParser 10', () {
    _expectMultipart(bytewise: true);
  });
  test('xterm IIPHeaderParser 11', () {
    _expectEndMarker('FileEnd', IipSequenceType.fileEnd, bytewise: false);
  });
  test('xterm IIPHeaderParser 12', () {
    _expectEndMarker('FileEnd', IipSequenceType.fileEnd, bytewise: true);
  });
  test('xterm IIPHeaderParser 13', () {
    _expectEndMarker(
      'ReportCellSize',
      IipSequenceType.reportCellSize,
      bytewise: false,
    );
  });
  test('xterm IIPHeaderParser 14', () {
    _expectEndMarker(
      'ReportCellSize',
      IipSequenceType.reportCellSize,
      bytewise: true,
    );
  });
}

const List<_Case> _cases = <_Case>[
  _Case('File=size=123456;name=dGVzdA==:', <String, Object?>{
    'type': IipSequenceType.file,
    'name': 'test',
    'size': 123456,
  }),
  _Case('File=size=123456;name=dGVzdA:', <String, Object?>{
    'type': IipSequenceType.file,
    'name': 'test',
    'size': 123456,
  }),
  _Case('File=size=123456;name=w7xtbMOkdXTDnw==:', <String, Object?>{
    'type': IipSequenceType.file,
    'name': 'ümläutß',
    'size': 123456,
  }),
  _Case('File=size=123456;name=w7xtbMOkdXTDnw:', <String, Object?>{
    'type': IipSequenceType.file,
    'name': 'ümläutß',
    'size': 123456,
  }),
  _Case(
    'File=inline=1;width=10px;height=20%;preserveAspectRatio=1;'
    'size=123456;name=w7xtbMOkdXTDnw:',
    <String, Object?>{
      'type': IipSequenceType.file,
      'inline': 1,
      'width': '10px',
      'height': '20%',
      'preserveAspectRatio': 1,
      'size': 123456,
      'name': 'ümläutß',
    },
  ),
  _Case(
    'File=inline=1;width=auto;height=20;preserveAspectRatio=1;'
    'size=123456;name=w7xtbMOkdXTDnw:',
    <String, Object?>{
      'type': IipSequenceType.file,
      'inline': 1,
      'width': 'auto',
      'height': '20',
      'preserveAspectRatio': 1,
      'size': 123456,
      'name': 'ümläutß',
    },
  ),
];

void _expectFirstCaseAfterReset(IipHeaderParser parser) {
  parser.reset();
  final example = _cases.first;
  final input = _codePoints(example.source);
  expect(parser.parse(input, 0, input.length), input.length);
  expect(parser.state, IipHeaderState.end);
  expect(parser.fields, example.fields);
}

void _expectMultipart({required bool bytewise}) {
  final parser = IipHeaderParser();
  final input = _codePoints(
    'MultipartFile=inline=1;width=10px;height=20%;preserveAspectRatio=1;'
    'size=123456;name=w7xtbMOkdXTDnw',
  );
  final result = bytewise
      ? _parseBytewise(parser, input)
      : parser.parse(input, 0, input.length);
  expect(result, -2);
  expect(parser.state, IipHeaderState.value);
  expect(parser.end(), 0);
  expect(parser.state, IipHeaderState.end);
  expect(parser.fields, <String, Object?>{
    'type': IipSequenceType.multipartFile,
    'inline': 1,
    'width': '10px',
    'height': '20%',
    'preserveAspectRatio': 1,
    'size': 123456,
    'name': 'ümläutß',
  });
}

void _expectEndMarker(
  String marker,
  IipSequenceType type, {
  required bool bytewise,
}) {
  final parser = IipHeaderParser();
  final input = _codePoints(marker);
  final result = bytewise
      ? _parseBytewise(parser, input)
      : parser.parse(input, 0, input.length);
  expect(result, -2);
  expect(parser.state, IipHeaderState.start);
  expect(parser.end(), 0);
  expect(parser.state, IipHeaderState.end);
  expect(parser.fields, <String, Object?>{'type': type});
}

int _parseBytewise(IipHeaderParser parser, Uint32List input) {
  var result = -2;
  var position = 0;
  while (result == -2 && position < input.length) {
    result = parser.parse(
      Uint32List.fromList(<int>[input[position++]]),
      0,
      1,
    );
  }
  return result;
}

Uint32List _codePoints(String value) => Uint32List.fromList(value.codeUnits);

final class _Case {
  const _Case(this.source, this.fields);

  final String source;
  final Map<String, Object?> fields;
}
