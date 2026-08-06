import Foundation

/// A drop region in physical pixels, relative to the view origin.
public struct DropwellRect: Equatable {
  public let left: Double
  public let top: Double
  public let right: Double
  public let bottom: Double

  public init(left: Double, top: Double, right: Double, bottom: Double) {
    self.left = left
    self.top = top
    self.right = right
    self.bottom = bottom
  }

  /// Whether this rectangle contains the point, top-left inclusive.
  public func contains(x: Double, y: Double) -> Bool {
    x >= left && x < right && y >= top && y < bottom
  }
}

/// Pure data handling for the macOS implementation.
///
/// None of this touches AppKit or a window, so the XCTest target can reach all
/// of it. The coordinate conversion in particular is where macOS differs from
/// every other platform this package supports: AppKit measures from the bottom
/// left and Flutter from the top left, so a drop lands in the mirrored region
/// unless the flip is applied exactly once.
public enum DropwellData {
  /// Parses a flat `[left, top, right, bottom, ...]` list of physical pixels.
  ///
  /// Returns `nil` when the length is not a multiple of four, which means Dart
  /// and this code disagree about the wire format rather than that the app has
  /// no drop regions.
  public static func parseRegions(_ flat: [Double]) -> [DropwellRect]? {
    guard flat.count % 4 == 0 else { return nil }
    return stride(from: 0, to: flat.count, by: 4).map { index in
      DropwellRect(
        left: flat[index], top: flat[index + 1],
        right: flat[index + 2], bottom: flat[index + 3])
    }
  }

  /// Whether any region contains the point.
  public static func anyContains(_ regions: [DropwellRect], x: Double, y: Double)
    -> Bool
  {
    regions.contains { $0.contains(x: x, y: y) }
  }

  /// Converts an AppKit view point to the physical pixels Dart publishes in.
  ///
  /// AppKit's origin is the bottom left of the view and Flutter's is the top
  /// left, so the vertical axis is flipped before scaling.
  public static func physicalPoint(
    viewPoint: CGPoint, viewHeight: CGFloat, scale: CGFloat
  ) -> CGPoint {
    CGPoint(
      x: viewPoint.x * scale,
      y: (viewHeight - viewPoint.y) * scale)
  }

  /// Media type for a file name, or `nil` when unknown.
  ///
  /// macOS reports no media type for a dropped file, and a consumer that wants
  /// one should not have to re-derive it from an extension in every app.
  public static func mimeFromFileName(_ fileName: String) -> String? {
    guard let dot = fileName.lastIndex(of: "."), dot < fileName.index(before: fileName.endIndex)
    else { return nil }
    switch fileName[fileName.index(after: dot)...].lowercased() {
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "webp": return "image/webp"
    case "gif": return "image/gif"
    case "bmp": return "image/bmp"
    case "pdf": return "application/pdf"
    case "json": return "application/json"
    case "csv": return "text/csv"
    case "txt", "md", "log": return "text/plain"
    default: return nil
    }
  }
}
