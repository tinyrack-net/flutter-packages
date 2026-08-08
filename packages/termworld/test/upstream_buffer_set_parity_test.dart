import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/termworld_headless.dart';

void main() {
  late TerminalBufferNamespace bufferSet;

  setUp(() {
    bufferSet = TerminalBufferNamespace(
      columns: 80,
      rows: 24,
      scrollback: 1000,
    );
  });

  tearDown(() {
    bufferSet.dispose();
  });

  group('BufferSet', () {
    group('constructor', () {
      test('should create two different buffers: alt and normal', () {
        expect(bufferSet.normal, isNot(same(bufferSet.alternate)));
      });
    });

    group('activateNormalBuffer', () {
      test('should set the normal buffer as the currently active buffer', () {
        bufferSet.useNormal();
        expect(bufferSet.active, same(bufferSet.normal));
      });
    });

    group('activateAltBuffer', () {
      test('should set the alt buffer as the currently active buffer', () {
        bufferSet.useAlternate();
        expect(bufferSet.active, same(bufferSet.alternate));
      });
    });

    group('cursor handling when swapping buffers', () {
      test('should keep the cursor stationary when activating alt buffer', () {
        bufferSet.normal
          ..cursorX = 30
          ..cursorY = 10;
        bufferSet.useAlternate();
        expect(bufferSet.active.cursorX, 30);
        expect(bufferSet.active.cursorY, 10);
      });

      test(
        'should keep the cursor stationary when activating normal buffer',
        () {
          bufferSet.useAlternate();
          bufferSet.alternate
            ..cursorX = 30
            ..cursorY = 10;
          bufferSet.useNormal();
          expect(bufferSet.active.cursorX, 30);
          expect(bufferSet.active.cursorY, 10);
        },
      );
    });

    group('markers', () {
      test('should clear the markers when the buffer is switched', () {
        bufferSet.useAlternate();
        final marker = bufferSet.alternate.addMarker(1);
        expect(bufferSet.alternate.markers, hasLength(1));
        bufferSet.useNormal();
        expect(bufferSet.alternate.markers, isEmpty);
        expect(marker.isDisposed, isTrue);
      });
    });

    group('lifecycle', () {
      test('should dispose previous buffers on reset', () {
        final oldNormal = bufferSet.normal;
        final oldAlternate = bufferSet.alternate;
        bufferSet.reset();
        expect(bufferSet.normal, isNot(same(oldNormal)));
        expect(bufferSet.alternate, isNot(same(oldAlternate)));
        expect(oldNormal.isDisposed, isTrue);
        expect(oldAlternate.isDisposed, isTrue);
      });

      test('should dispose both buffers when disposed', () {
        final normal = bufferSet.normal;
        final alternate = bufferSet.alternate;
        bufferSet.dispose();
        expect(normal.isDisposed, isTrue);
        expect(alternate.isDisposed, isTrue);
      });
    });
  });
}
