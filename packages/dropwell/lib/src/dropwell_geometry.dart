import 'dart:ui';

/// Coordinate helpers shared by the registry and its tests.
///
/// Native code speaks physical pixels relative to the view origin; Flutter
/// speaks logical pixels. Every conversion in this package goes through these
/// two functions so the rounding rule is stated once.
abstract final class DropwellGeometry {
  /// Converts a logical-pixel rectangle to physical pixels.
  static Rect toPhysical(Rect logical, double devicePixelRatio) =>
      Rect.fromLTRB(
        logical.left * devicePixelRatio,
        logical.top * devicePixelRatio,
        logical.right * devicePixelRatio,
        logical.bottom * devicePixelRatio,
      );

  /// Converts a physical-pixel point to logical pixels.
  static Offset toLogical(Offset physical, double devicePixelRatio) =>
      physical / devicePixelRatio;

  /// Returns the index of the topmost rectangle containing [point].
  ///
  /// Later entries win, matching paint order: a region mounted inside another
  /// region is registered after it and must receive the drop. Returns `null`
  /// when no rectangle contains the point.
  static int? topmostRegionAt(List<Rect> regions, Offset point) {
    for (var index = regions.length - 1; index >= 0; index--) {
      if (regions[index].contains(point)) return index;
    }
    return null;
  }
}
