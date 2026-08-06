import 'dart:ui';

import 'package:dropwell/src/dropwell_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toPhysical', () {
    test('scales every edge by the device pixel ratio', () {
      expect(
        DropwellGeometry.toPhysical(const Rect.fromLTRB(1, 2, 3, 4), 2.5),
        const Rect.fromLTRB(2.5, 5, 7.5, 10),
      );
    });

    test('is an identity at a ratio of one', () {
      const logical = Rect.fromLTRB(10, 20, 30, 40);
      expect(DropwellGeometry.toPhysical(logical, 1), logical);
    });
  });

  group('toLogical', () {
    test('inverts toPhysical', () {
      const logical = Rect.fromLTRB(1.5, 2.5, 3.5, 4.5);
      final physical = DropwellGeometry.toPhysical(logical, 3);

      expect(
        DropwellGeometry.toLogical(physical.topLeft, 3),
        logical.topLeft,
      );
    });
  });

  group('topmostRegionAt', () {
    test('returns null when no region contains the point', () {
      expect(
        DropwellGeometry.topmostRegionAt(const <Rect>[
          Rect.fromLTRB(0, 0, 10, 10),
        ], const Offset(50, 50)),
        isNull,
      );
    });

    test('returns null for an empty region list', () {
      expect(
        DropwellGeometry.topmostRegionAt(const <Rect>[], Offset.zero),
        isNull,
      );
    });

    test('returns the single containing region', () {
      expect(
        DropwellGeometry.topmostRegionAt(const <Rect>[
          Rect.fromLTRB(0, 0, 10, 10),
          Rect.fromLTRB(20, 20, 30, 30),
        ], const Offset(25, 25)),
        1,
      );
    });

    test('prefers the later region when regions overlap', () {
      expect(
        DropwellGeometry.topmostRegionAt(const <Rect>[
          Rect.fromLTRB(0, 0, 100, 100),
          Rect.fromLTRB(10, 10, 20, 20),
        ], const Offset(15, 15)),
        1,
      );
    });

    test(
      'treats the top-left edge as inside and the bottom-right as outside',
      () {
        const regions = <Rect>[Rect.fromLTRB(0, 0, 10, 10)];

        expect(DropwellGeometry.topmostRegionAt(regions, Offset.zero), 0);
        expect(
          DropwellGeometry.topmostRegionAt(regions, const Offset(10, 10)),
          isNull,
        );
      },
    );
  });
}
