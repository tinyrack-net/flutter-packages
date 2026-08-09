import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/core/buffer.dart';
import 'package:termworld/src/core/selection_render_model.dart';

void main() {
  group('SelectionRenderModel', () {
    test('clears empty and offscreen selections', () {
      final model = createSelectionRenderModel()
        ..update(
          rows: 5,
          viewportY: 10,
          start: const TerminalBufferPosition(1, 2),
          end: const TerminalBufferPosition(4, 3),
        );
      expect(model.hasSelection, isFalse);

      model.update(
        rows: 5,
        viewportY: 0,
        start: const TerminalBufferPosition(1, 2),
        end: const TerminalBufferPosition(1, 2),
      );
      expect(model.hasSelection, isFalse);
    });

    test('projects, caps and tests a linear selection', () {
      final model = createSelectionRenderModel()
        ..update(
          rows: 5,
          viewportY: 10,
          start: const TerminalBufferPosition(2, 9),
          end: const TerminalBufferPosition(3, 13),
        );
      expect(model.hasSelection, isTrue);
      expect(model.viewportStartRow, -1);
      expect(model.viewportCappedStartRow, 0);
      expect(model.viewportEndRow, 3);
      expect(model.isCellSelected(x: 0, y: 10, viewportY: 10), isTrue);
      expect(model.isCellSelected(x: 3, y: 13, viewportY: 10), isFalse);
      expect(model.isCellSelected(x: 2, y: 13, viewportY: 10), isTrue);
    });

    test('tests forward and reverse column selections', () {
      final model = createSelectionRenderModel()
        ..update(
          rows: 5,
          viewportY: 0,
          start: const TerminalBufferPosition(1, 1),
          end: const TerminalBufferPosition(4, 3),
          columnMode: true,
        );
      expect(model.isCellSelected(x: 1, y: 2, viewportY: 0), isTrue);
      expect(model.isCellSelected(x: 4, y: 2, viewportY: 0), isFalse);

      model.update(
        rows: 5,
        viewportY: 0,
        start: const TerminalBufferPosition(4, 1),
        end: const TerminalBufferPosition(1, 3),
        columnMode: true,
      );
      expect(model.isCellSelected(x: 1, y: 2, viewportY: 0), isTrue);
      expect(model.isCellSelected(x: 4, y: 2, viewportY: 0), isFalse);
    });
  });
}
