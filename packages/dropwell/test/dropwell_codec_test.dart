import 'dart:typed_data';
import 'dart:ui';

import 'package:dropwell/dropwell.dart';
import 'package:dropwell/src/dropwell_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeFiles', () {
    test('returns an empty list for a null payload', () {
      expect(DropwellCodec.decodeFiles(null), isEmpty);
    });

    test('preserves order, names, and media types', () {
      final files = DropwellCodec.decodeFiles(<Object?>[
        <Object?, Object?>{
          'fileName': 'first.txt',
          'mimeType': 'text/plain',
          'path': '/tmp/first.txt',
        },
        <Object?, Object?>{
          'fileName': 'second.png',
          'mimeType': 'image/png',
          'bytes': Uint8List.fromList(<int>[1, 2, 3]),
        },
      ]);

      expect(files.map((file) => file.fileName), <String>[
        'first.txt',
        'second.png',
      ]);
      expect(files.first.path, '/tmp/first.txt');
      expect(files.first.bytes, isNull);
      expect(files.last.bytes, <int>[1, 2, 3]);
      expect(files.last.path, isNull);
      expect(files.last.mimeType, 'image/png');
    });

    test('keeps a missing media type null rather than guessing', () {
      final files = DropwellCodec.decodeFiles(<Object?>[
        <Object?, Object?>{'fileName': 'notes.md', 'path': '/tmp/notes.md'},
      ]);

      expect(files.single.mimeType, isNull);
    });

    test('rejects a payload that is not a list', () {
      expect(
        () => DropwellCodec.decodeFiles('nope'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an entry that is not a map', () {
      expect(
        () => DropwellCodec.decodeFiles(<Object?>['nope']),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a missing or empty file name', () {
      expect(
        () => DropwellCodec.decodeFiles(<Object?>[
          <Object?, Object?>{'path': '/tmp/x'},
        ]),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => DropwellCodec.decodeFiles(<Object?>[
          <Object?, Object?>{'fileName': '', 'path': '/tmp/x'},
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-string media type', () {
      expect(
        () => DropwellCodec.decodeFiles(<Object?>[
          <Object?, Object?>{
            'fileName': 'x.txt',
            'mimeType': 7,
            'path': '/tmp/x',
          },
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a file carrying neither a path nor bytes', () {
      expect(
        () => DropwellCodec.decodeFiles(<Object?>[
          <Object?, Object?>{'fileName': 'x.txt'},
        ]),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a file carrying both a path and bytes', () {
      expect(
        () => DropwellCodec.decodeFiles(<Object?>[
          <Object?, Object?>{
            'fileName': 'x.txt',
            'path': '/tmp/x',
            'bytes': Uint8List(1),
          },
        ]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('encodeFile', () {
    test('round-trips a path-backed file', () {
      const original = DropwellFile.path(
        fileName: 'résumé 📄.pdf',
        path: '/tmp/r.pdf',
        mimeType: 'application/pdf',
      );

      final decoded = DropwellCodec.decodeFile(
        DropwellCodec.encodeFile(original),
      );

      expect(decoded.fileName, original.fileName);
      expect(decoded.path, original.path);
      expect(decoded.mimeType, original.mimeType);
      expect(decoded.bytes, isNull);
    });

    test('round-trips a bytes-backed file without a media type', () {
      final original = DropwellFile.bytes(
        fileName: '한글 이름.png',
        bytes: Uint8List.fromList(<int>[9, 8, 7]),
      );

      final decoded = DropwellCodec.decodeFile(
        DropwellCodec.encodeFile(original),
      );

      expect(decoded.fileName, original.fileName);
      expect(decoded.bytes, original.bytes);
      expect(decoded.mimeType, isNull);
      expect(decoded.path, isNull);
    });
  });

  group('decodeDragEvent', () {
    test('reads a positioned phase', () {
      final event = DropwellCodec.decodeDragEvent(<Object?, Object?>{
        'phase': 'over',
        'x': 12.5,
        'y': 30.0,
      });

      expect(event.phase, DropwellDragPhase.over);
      expect(event.physicalPosition, const Offset(12.5, 30));
      expect(event.files, isEmpty);
    });

    test('reads a perform phase with files', () {
      final event = DropwellCodec.decodeDragEvent(<Object?, Object?>{
        'phase': 'perform',
        'x': 1.0,
        'y': 2.0,
        'files': <Object?>[
          <Object?, Object?>{'fileName': 'a.txt', 'path': '/tmp/a.txt'},
        ],
      });

      expect(event.phase, DropwellDragPhase.perform);
      expect(event.files.single.fileName, 'a.txt');
    });

    test('ignores a position on leave', () {
      final event = DropwellCodec.decodeDragEvent(<Object?, Object?>{
        'phase': 'leave',
      });

      expect(event.physicalPosition, Offset.zero);
    });

    test('rejects an unknown phase', () {
      expect(
        () => DropwellCodec.decodeDragEvent(<Object?, Object?>{
          'phase': 'hover',
          'x': 0.0,
          'y': 0.0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects files on a phase that cannot carry them', () {
      expect(
        () => DropwellCodec.decodeDragEvent(<Object?, Object?>{
          'phase': 'enter',
          'x': 0.0,
          'y': 0.0,
          'files': <Object?>[
            <Object?, Object?>{'fileName': 'a.txt', 'path': '/tmp/a.txt'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-double position', () {
      expect(
        () => DropwellCodec.decodeDragEvent(<Object?, Object?>{
          'phase': 'over',
          'x': 1,
          'y': 2,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a payload that is not a map', () {
      expect(
        () => DropwellCodec.decodeDragEvent(<Object?>[]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('encodeRegions', () {
    test('flattens rectangles in order', () {
      expect(
        DropwellCodec.encodeRegions(const <Rect>[
          Rect.fromLTRB(0, 1, 2, 3),
          Rect.fromLTRB(4, 5, 6, 7),
        ]),
        <double>[0, 1, 2, 3, 4, 5, 6, 7],
      );
    });

    test('encodes an empty list', () {
      expect(DropwellCodec.encodeRegions(const <Rect>[]), isEmpty);
    });

    test('produces a typed buffer platform code can read as doubles', () {
      // A plain List<double> crosses the channel as boxed values that no
      // platform can decode as a double array, so the type is the contract.
      expect(
        DropwellCodec.encodeRegions(const <Rect>[Rect.fromLTRB(0, 1, 2, 3)]),
        isA<Float64List>(),
      );
    });
  });
}
