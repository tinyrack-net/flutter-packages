import Flutter
import UIKit

extension DropwellPlugin {
  #if DEBUG

    /// Registers the Debug-only channel the conformance suite drives.
    func registerTestingChannel(with registrar: FlutterPluginRegistrar) {
      let channel = FlutterMethodChannel(
        name: "dropwell/testing", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        DropwellPlugin.handleTestingCall(call, result: result)
      }
    }

    private static func handleTestingCall(
      _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
      switch call.method {
      case "clearSystemClipboard":
        UIPasteboard.general.items = []
        result(nil)

      case "setSystemClipboard":
        guard let arguments = call.arguments as? [String: Any] else {
          result(
            FlutterError(
              code: "bad-arguments", message: "setSystemClipboard needs a map",
              details: nil))
          return
        }
        let files = arguments["files"] as? [[String: Any]] ?? []
        if arguments["asBitmap"] as? Bool ?? false {
          guard let bytes = bytesOf(files.first) else {
            result(
              FlutterError(
                code: "bad-arguments", message: "a bitmap needs bytes",
                details: nil))
            return
          }
          UIPasteboard.general.items = [["public.png": bytes]]
        } else {
          UIPasteboard.general.urls = materialize(files)
        }
        result(nil)

      case "readFile":
        guard let path = call.arguments as? String,
          let data = FileManager.default.contents(atPath: path)
        else {
          result(
            FlutterError(
              code: "io", message: "could not read the reported path",
              details: nil))
          return
        }
        result(FlutterStandardTypedData(bytes: data))

      default:
        // iOS declares no drop support, so a synthesized drag has nothing to
        // reach and must not silently look like it worked.
        result(FlutterMethodNotImplemented)
      }
    }

    private static func bytesOf(_ file: [String: Any]?) -> Data? {
      (file?["bytes"] as? FlutterStandardTypedData)?.data
    }

    /// Writes payloads into the temporary directory under their own names.
    ///
    /// The pasteboard hands over *files*, so a suite that only ever passed
    /// bytes would never exercise the path real users take.
    private static func materialize(_ files: [[String: Any]]) -> [URL] {
      let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("dropwell", isDirectory: true)
      try? FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true)
      return files.compactMap { file in
        if let existing = file["path"] as? String {
          return URL(fileURLWithPath: existing)
        }
        guard let name = file["fileName"] as? String else { return nil }
        let url = directory.appendingPathComponent(name)
        let bytes = bytesOf(file) ?? Data()
        return (try? bytes.write(to: url)) == nil ? nil : url
      }
    }

  #else

    /// Registers nothing outside a Debug build.
    ///
    /// The channel name never reaches a release binary, which
    /// `tool/verify_release_hooks.dart` checks by searching the built artifact
    /// rather than trusting this guard.
    func registerTestingChannel(with registrar: FlutterPluginRegistrar) {}

  #endif
}
