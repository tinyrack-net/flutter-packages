import Flutter
import UIKit

/// iOS implementation of the dropwell platform boundary.
///
/// iOS has no notion of dropping a file onto an app from outside it, so this
/// half implements the pasteboard only and Dart reports `supportsDrop` as
/// false. A pasteboard item is data rather than a path, so every file comes
/// back as bytes.
public class DropwellPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dropwell", binaryMessenger: registrar.messenger())
    let instance = DropwellPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.registerTestingChannel(with: registrar)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "readClipboardFiles":
      result(DropwellPlugin.readPasteboard(UIPasteboard.general))
    case "publishDropRegions":
      // iOS never delivers a drop, so a published region list is accepted and
      // ignored rather than treated as a caller error.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Reads every file this package can represent out of a pasteboard.
  ///
  /// File URLs come first: a file copied in Files is a file, and reporting it
  /// as anonymous bytes would throw away its name.
  static func readPasteboard(_ pasteboard: UIPasteboard) -> [[String: Any]] {
    if let urls = pasteboard.urls?.filter({ $0.isFileURL }), !urls.isEmpty {
      return urls.compactMap { url in
        guard let data = try? Data(contentsOf: url) else { return nil }
        let name = url.lastPathComponent
        var entry: [String: Any] = [
          "fileName": name,
          "bytes": FlutterStandardTypedData(bytes: data),
        ]
        entry["mimeType"] = DropwellData.mimeFromFileName(name) as Any
        return entry
      }
    }
    for identifier in pasteboard.types {
      guard let mime = DropwellData.mimeFromTypeIdentifier(identifier),
        let data = pasteboard.data(forPasteboardType: identifier)
      else { continue }
      return [
        [
          "fileName": DropwellData.defaultFileName(forMime: mime),
          "mimeType": mime,
          "bytes": FlutterStandardTypedData(bytes: data),
        ]
      ]
    }
    return []
  }
}
