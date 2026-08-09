import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/ligature_ranges.dart';

void main() {
  group('addon-ligatures - mergeRange', () {
    test('inserts a new range before the existing ones', () {
      expect(
        mergeLigatureRange(<(int, int)>[(1, 2), (2, 3)], 0, 1),
        <(int, int)>[(0, 1), (1, 2), (2, 3)],
      );
    });

    test('inserts in between two ranges', () {
      expect(
        mergeLigatureRange(<(int, int)>[(0, 2), (4, 6)], 2, 4),
        <(int, int)>[(0, 2), (2, 4), (4, 6)],
      );
    });

    test('inserts after the last range', () {
      expect(
        mergeLigatureRange(<(int, int)>[(0, 2), (4, 6)], 6, 8),
        <(int, int)>[(0, 2), (4, 6), (6, 8)],
      );
    });

    test('extends the beginning of a range', () {
      expect(
        mergeLigatureRange(<(int, int)>[(0, 2), (4, 6)], 3, 5),
        <(int, int)>[(0, 2), (3, 6)],
      );
    });

    test('extends the end of a range', () {
      expect(
        mergeLigatureRange(<(int, int)>[(0, 2), (4, 6)], 1, 4),
        <(int, int)>[(0, 4), (4, 6)],
      );
    });

    test('extends the last range', () {
      expect(
        mergeLigatureRange(<(int, int)>[(0, 2), (4, 6)], 5, 7),
        <(int, int)>[(0, 2), (4, 7)],
      );
    });

    test('connects two ranges', () {
      expect(
        mergeLigatureRange(<(int, int)>[(0, 2), (4, 6)], 1, 5),
        <(int, int)>[(0, 6)],
      );
    });

    test('connects more than two ranges', () {
      expect(
        mergeLigatureRange(
          <(int, int)>[(0, 2), (4, 6), (8, 10), (12, 14)],
          1,
          10,
        ),
        <(int, int)>[(0, 10), (12, 14)],
      );
    });
  });
}
