import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_utils.dart';

void main() {
  group('polyfill conformance tests', () {
    group('TypedArray.slice', () {
      group('should work with all typed array types', () {
        test('Uint8Array', () => _expectTypedSlices(Uint8List(5), 65535));
        test('Uint16Array', () => _expectTypedSlices(Uint16List(5), 65535));
        test('Uint32Array', () => _expectTypedSlices(Uint32List(5), 65537));
        test('Int8Array', () => _expectTypedSlices(Int8List(5), 65537));
        test('Int16Array', () => _expectTypedSlices(Int16List(5), 65535));
        test('Int32Array', () => _expectTypedSlices(Int32List(5), 65537));
        test('Float32Array', () => _expectTypedSlices(Float32List(5), 65537));
        test('Float64Array', () => _expectTypedSlices(Float64List(5), 65537));
        test(
          'Uint8ClampedArray',
          () => _expectTypedSlices(Uint8ClampedList(5), 65537),
        );
      });

      test('start', () {
        final values = Uint32List.fromList(<int>[1, 2, 3, 4, 5]);
        for (final start in <int>[-1, 0, 1, 2, 3, 4, 5]) {
          expect(
            sliceTerminalTypedArray(values, start: start),
            values.sublist(_normalizedStart(values.length, start)),
          );
        }
      });

      test('end', () {
        final values = Uint32List.fromList(<int>[1, 2, 3, 4, 5]);
        for (final end in <int>[-2, 3, 8]) {
          for (final start in <int>[-1, 0, 1, 2, 3, 4, 5]) {
            final normalizedEnd = end < 0
                ? (values.length + end).clamp(0, values.length)
                : end.clamp(0, values.length);
            final normalizedStart = _normalizedStart(
              values.length,
              start,
            ).clamp(0, normalizedEnd);
            expect(
              sliceTerminalTypedArray(values, start: start, end: end),
              values.sublist(normalizedStart, normalizedEnd),
            );
          }
        }
      });
    });
  });

  group('CharAtlasUtils', () {
    group('configEquals', () {
      test('should return true for identical configs', () {
        expect(
          terminalCharAtlasConfigEquals(_config(), _config()),
          isTrue,
        );
      });

      test('should return false when deviceMaxTextureSize differs', () {
        expect(
          terminalCharAtlasConfigEquals(
            _config(),
            _config(deviceMaxTextureSize: 8192),
          ),
          isFalse,
        );
      });

      test('should return false when deviceCellWidth differs', () {
        expect(
          terminalCharAtlasConfigEquals(
            _config(),
            _config(deviceCellWidth: 11),
          ),
          isFalse,
        );
      });

      test('should return false when deviceCellHeight differs', () {
        expect(
          terminalCharAtlasConfigEquals(
            _config(),
            _config(deviceCellHeight: 21),
          ),
          isFalse,
        );
      });
    });
  });
}

void _expectTypedSlices<T extends List<num>>(T values, int largeStart) {
  expect(sliceTerminalTypedArray(values, start: 2), isA<T>());
  expect(sliceTerminalTypedArray(values, start: 2), values.sublist(2));
  expect(sliceTerminalTypedArray(values, start: largeStart), isEmpty);
  expect(sliceTerminalTypedArray(values, start: -1), values.sublist(4));
}

int _normalizedStart(int length, int start) =>
    start < 0 ? (length + start).clamp(0, length) : start.clamp(0, length);

TerminalCharAtlasConfig _config({
  int deviceMaxTextureSize = 4096,
  double deviceCellWidth = 10,
  double deviceCellHeight = 20,
}) => TerminalCharAtlasConfig(
  ansi: List<int>.filled(256, 0xffffffff),
  deviceMaxTextureSize: deviceMaxTextureSize,
  deviceCellWidth: deviceCellWidth,
  deviceCellHeight: deviceCellHeight,
);
