import Cocoa
import FlutterMacOS

/// macOS implementation of the dropwell platform boundary.
public class DropwellPlugin: NSObject, FlutterPlugin {
  var channel: FlutterMethodChannel?
  private var regions: [DropwellRect] = []
  private weak var dragView: DropwellDragView?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dropwell", binaryMessenger: registrar.messenger)
    let instance = DropwellPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.attachDragView(to: registrar.view)
    instance.registerTestingChannel(with: registrar)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "readClipboardFiles":
      result(DropwellPlugin.readPasteboard(NSPasteboard.general))
    case "publishDropRegions":
      guard let flat = call.arguments as? FlutterStandardTypedData else {
        result(
          FlutterError(
            code: "bad-arguments",
            message: "publishDropRegions needs a double list", details: nil))
        return
      }
      guard let parsed = DropwellData.parseRegions(flat.toDoubleArray()) else {
        result(
          FlutterError(
            code: "bad-arguments",
            message: "publishDropRegions needs groups of four doubles",
            details: nil))
        return
      }
      regions = parsed
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Whether a published drop region contains the physical-pixel point.
  func accepts(x: Double, y: Double) -> Bool {
    DropwellData.anyContains(regions, x: x, y: y)
  }

  /// Reports a positioned drag phase to Dart.
  func reportDrag(phase: String, x: Double, y: Double) {
    channel?.invokeMethod(
      "drag", arguments: ["phase": phase, "x": x, "y": y, "files": []])
  }

  /// Reports a completed drop carrying whatever the pasteboard holds.
  func reportDrop(x: Double, y: Double, pasteboard: NSPasteboard) {
    channel?.invokeMethod(
      "drag",
      arguments: [
        "phase": "perform", "x": x, "y": y,
        "files": DropwellPlugin.readPasteboard(pasteboard),
      ])
  }

  /// Reads every file this package can represent out of a pasteboard.
  ///
  /// A drop payload and the clipboard are both pasteboards, so one reader
  /// serves both and neither can quietly support a format the other does not.
  /// File URLs come first: an image copied out of Finder is a file, and
  /// reporting it as anonymous pixels would throw away its name.
  static func readPasteboard(_ pasteboard: NSPasteboard) -> [[String: Any]] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true
    ]
    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty
    {
      return urls.map { url in
        var entry: [String: Any] = [
          "fileName": url.lastPathComponent,
          "path": url.path,
        ]
        entry["mimeType"] =
          DropwellData.mimeFromFileName(url.lastPathComponent) as Any
        return entry
      }
    }
    if let png = pasteboard.data(forType: .png) {
      return [imageEntry(png)]
    }
    if let tiff = pasteboard.data(forType: .tiff),
      let png = NSBitmapImageRep(data: tiff)?
        .representation(using: .png, properties: [:])
    {
      return [imageEntry(png)]
    }
    return []
  }

  private static func imageEntry(_ png: Data) -> [String: Any] {
    [
      "fileName": "pasted-image.png",
      "mimeType": "image/png",
      "bytes": FlutterStandardTypedData(bytes: png),
    ]
  }

  private func attachDragView(to view: NSView?) {
    guard let view = view else { return }
    let dragView = DropwellDragView(frame: view.bounds)
    dragView.autoresizingMask = [.width, .height]
    dragView.plugin = self
    dragView.registerForDraggedTypes([.fileURL, .png, .tiff])
    view.addSubview(dragView)
    self.dragView = dragView
  }
}

/// A transparent subview that owns the dragging destination.
///
/// The Flutter view cannot be subclassed, so the destination lives in an
/// overlay that resizes with it. The overlay implements no mouse handling, so
/// AppKit's responder chain hands every ordinary event straight back to the
/// Flutter view underneath.
class DropwellDragView: NSView {
  weak var plugin: DropwellPlugin?

  private func physicalPoint(_ sender: NSDraggingInfo) -> CGPoint {
    DropwellData.physicalPoint(
      viewPoint: convert(sender.draggingLocation, from: nil),
      viewHeight: bounds.height,
      scale: window?.backingScaleFactor ?? 1)
  }

  private func operation(at point: CGPoint) -> NSDragOperation {
    (plugin?.accepts(x: Double(point.x), y: Double(point.y)) ?? false)
      ? .copy : []
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let point = physicalPoint(sender)
    plugin?.reportDrag(phase: "enter", x: Double(point.x), y: Double(point.y))
    return operation(at: point)
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let point = physicalPoint(sender)
    plugin?.reportDrag(phase: "over", x: Double(point.x), y: Double(point.y))
    return operation(at: point)
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    plugin?.reportDrag(phase: "leave", x: 0, y: 0)
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    true
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let point = physicalPoint(sender)
    plugin?.reportDrop(
      x: Double(point.x), y: Double(point.y),
      pasteboard: sender.draggingPasteboard)
    return true
  }
}

extension FlutterStandardTypedData {
  /// Reads a Float64List sent from Dart as native doubles.
  func toDoubleArray() -> [Double] {
    data.withUnsafeBytes { raw in Array(raw.bindMemory(to: Double.self)) }
  }
}
