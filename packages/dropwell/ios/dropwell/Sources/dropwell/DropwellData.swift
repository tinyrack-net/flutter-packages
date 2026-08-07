import Foundation

/// Pure data handling for the iOS implementation.
///
/// Nothing here touches UIKit, so the XCTest target reaches all of it without
/// a running app. `UIPasteboard` reports a uniform type identifier rather than
/// a media type, and a consumer that wants one should not have to translate
/// Apple's identifiers in every app.
public enum DropwellData {
  /// Returns the final path component.
  public static func fileNameOf(_ path: String) -> String {
    (path as NSString).lastPathComponent
  }

  /// Media type for a file name, or `nil` when unknown.
  public static func mimeFromFileName(_ fileName: String) -> String? {
    guard let dot = fileName.lastIndex(of: "."),
      dot < fileName.index(before: fileName.endIndex)
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

  /// Media type for a uniform type identifier, or `nil` when unknown.
  public static func mimeFromTypeIdentifier(_ identifier: String) -> String? {
    switch identifier {
    case "public.png": return "image/png"
    case "public.jpeg": return "image/jpeg"
    case "org.webmproject.webp": return "image/webp"
    case "com.compuserve.gif": return "image/gif"
    case "com.adobe.pdf": return "application/pdf"
    case "public.plain-text", "public.utf8-plain-text": return "text/plain"
    default: return nil
    }
  }

  /// A file name for a pasted payload that arrived without one.
  public static func defaultFileName(forMime mime: String?) -> String {
    switch mime {
    case "image/png": return "pasted-image.png"
    case "image/jpeg": return "pasted-image.jpg"
    case "image/webp": return "pasted-image.webp"
    case "image/gif": return "pasted-image.gif"
    default: return "pasted-file"
    }
  }
}
