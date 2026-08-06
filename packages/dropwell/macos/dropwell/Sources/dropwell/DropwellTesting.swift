import Cocoa
import FlutterMacOS

extension DropwellPlugin {
  #if DEBUG

    /// Registers the Debug-only channel the conformance suite drives.
    ///
    /// A synthesized drop is handed a real `NSPasteboard` and goes through the
    /// same reader an AppKit drag would, so only AppKit's own delivery of the
    /// dragging session sits outside the conformance suite.
    func registerTestingChannel(with registrar: FlutterPluginRegistrar) {
      let channel = FlutterMethodChannel(
        name: "dropwell/testing", binaryMessenger: registrar.messenger)
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleTestingCall(call, result: result)
      }
    }

    private func handleTestingCall(
      _ call: FlutterMethodCall, result: @escaping FlutterResult
    ) {
      switch call.method {
      case "clearSystemClipboard":
        NSPasteboard.general.clearContents()
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
        let asBitmap = arguments["asBitmap"] as? Bool ?? false
        NSPasteboard.general.clearContents()
        if asBitmap {
          guard let bytes = DropwellPlugin.bytesOf(files.first),
            let image = NSImage(data: bytes)
          else {
            result(
              FlutterError(
                code: "bad-arguments", message: "a bitmap needs bytes",
                details: nil))
            return
          }
          NSPasteboard.general.writeObjects([image])
        } else {
          let urls = DropwellPlugin.materialize(files).map { $0 as NSURL }
          NSPasteboard.general.writeObjects(urls)
        }
        result(nil)

      case "synthesizeDrag":
        guard let arguments = call.arguments as? [String: Any],
          let phase = arguments["phase"] as? String
        else {
          result(
            FlutterError(
              code: "bad-arguments", message: "synthesizeDrag needs a map",
              details: nil))
          return
        }
        let x = arguments["x"] as? Double ?? 0
        let y = arguments["y"] as? Double ?? 0
        switch phase {
        case "enter", "over":
          reportDrag(phase: phase, x: x, y: y)
        case "leave":
          reportDrag(phase: "leave", x: 0, y: 0)
        case "perform":
          let files = arguments["files"] as? [[String: Any]] ?? []
          let pasteboard = NSPasteboard(name: .init("dropwell.conformance"))
          pasteboard.clearContents()
          pasteboard.writeObjects(
            DropwellPlugin.materialize(files).map { $0 as NSURL })
          reportDrop(x: x, y: y, pasteboard: pasteboard)
        default:
          result(
            FlutterError(
              code: "bad-arguments", message: "unknown drag phase \(phase)",
              details: nil))
          return
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
        result(FlutterMethodNotImplemented)
      }
    }

    private static func bytesOf(_ file: [String: Any]?) -> Data? {
      (file?["bytes"] as? FlutterStandardTypedData)?.data
    }

    /// Writes payloads into the temporary directory under their own names.
    ///
    /// The clipboard and a drag payload both hand over *files*, so a suite that
    /// only ever passed bytes would never exercise the path real users take.
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
