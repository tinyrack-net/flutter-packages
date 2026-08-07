import Cocoa
import FlutterMacOS
import WebKit

public final class BrowsewellPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "net.tinyrack.browsewell/automation",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(BrowsewellPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "setViewport" {
      result(nil)
      return
    }
    let arguments = call.arguments as? [String: Any] ?? [:]
    guard let webView = Self.findWebView(
      in: NSApp.keyWindow?.contentView,
      nearX: (arguments["viewportLeft"] as? NSNumber)?.doubleValue ?? 0,
      top: (arguments["viewportTop"] as? NSNumber)?.doubleValue ?? 0
    ) else {
      result(FlutterError(code: "no_host", message: "No visible WKWebView is available.", details: nil))
      return
    }
    webView.window?.makeFirstResponder(webView)

    switch call.method {
    case "click", "hover":
      guard let point = Self.center(of: arguments["rect"], in: webView) else {
        result(FlutterError(code: "internal", message: "Element bounds are missing.", details: nil))
        return
      }
      Self.sendMouse(.mouseMoved, at: point, to: webView)
      if call.method == "click" {
        Self.sendMouse(.leftMouseDown, at: point, to: webView)
        Self.sendMouse(.leftMouseUp, at: point, to: webView)
      }
      result(nil)
    case "type":
      if arguments["replace"] as? Bool == true {
        Self.sendKey("a", code: 0, modifiers: .command, to: webView)
      }
      Self.sendText(arguments["text"] as? String ?? "", to: webView)
      result(nil)
    case "keypress":
      let key = arguments["key"] as? String ?? ""
      Self.sendNamedKey(key, to: webView)
      result(nil)
    case "select":
      Self.sendNamedKey("Home", to: webView)
      Self.sendText(arguments["value"] as? String ?? "", to: webView)
      Self.sendNamedKey("Enter", to: webView)
      result(nil)
    case "drag":
      guard
        let source = Self.center(of: arguments["source"], in: webView),
        let target = Self.center(of: arguments["target"], in: webView)
      else {
        result(FlutterError(code: "internal", message: "Drag bounds are missing.", details: nil))
        return
      }
      Self.sendDrag(from: source, to: target, in: webView, result: result)
    case "scroll":
      Self.sendScroll(
        deltaX: (arguments["deltaX"] as? NSNumber)?.doubleValue ?? 0,
        deltaY: (arguments["deltaY"] as? NSNumber)?.doubleValue ?? 0,
        to: webView
      )
      result(nil)
    case "screenshot":
      let configuration = WKSnapshotConfiguration()
      if arguments["fullPage"] as? Bool == true {
        webView.evaluateJavaScript(
          "[document.documentElement.scrollWidth, document.documentElement.scrollHeight]"
        ) { value, error in
          guard
            error == nil,
            let dimensions = value as? [NSNumber],
            dimensions.count == 2
          else {
            result(FlutterError(
              code: "internal",
              message: error?.localizedDescription ?? "Document size is unavailable.",
              details: nil
            ))
            return
          }
          configuration.rect = CGRect(
            origin: .zero,
            size: CGSize(width: dimensions[0].doubleValue, height: dimensions[1].doubleValue)
          )
          Self.takeSnapshot(of: webView, configuration: configuration, result: result)
        }
        return
      }
      Self.takeSnapshot(of: webView, configuration: configuration, result: result)
    case "upload":
      guard let path = (arguments["filePaths"] as? [String])?.first else {
        result(FlutterError(code: "denied", message: "Upload paths are missing.", details: nil))
        return
      }
      Self.sendNamedKey("Enter", to: webView)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        let panel = (NSApp.modalWindow as? NSOpenPanel)
          ?? NSApp.windows.compactMap { $0 as? NSOpenPanel }.first
        guard let panel else {
          result(FlutterError(code: "internal", message: "The file chooser did not open.", details: nil))
          return
        }
        let file = URL(fileURLWithPath: path)
        panel.directoryURL = file.deletingLastPathComponent()
        panel.nameFieldStringValue = file.lastPathComponent
        panel.ok(nil)
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func takeSnapshot(
    of webView: WKWebView,
    configuration: WKSnapshotConfiguration,
    result: @escaping FlutterResult
  ) {
    webView.takeSnapshot(with: configuration) { image, error in
      guard
        error == nil,
        let data = image?.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data),
        let png = bitmap.representation(using: .png, properties: [:])
      else {
        result(FlutterError(
          code: "internal",
          message: error?.localizedDescription ?? "Snapshot failed.",
          details: nil
        ))
        return
      }
      result(FlutterStandardTypedData(bytes: png))
    }
  }

  private static func sendScroll(deltaX: Double, deltaY: Double, to webView: WKWebView) {
    guard
      let window = webView.window,
      let event = NSEvent.scrollWheel(
        with: webView.convert(
          NSPoint(x: webView.bounds.midX, y: webView.bounds.midY),
          to: nil
        ),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        deltaX: -deltaX,
        deltaY: -deltaY,
        deltaZ: 0
      )
    else { return }
    webView.scrollWheel(with: event)
  }

  private static func findWebView(
    in root: NSView?,
    nearX x: Double,
    top: Double
  ) -> WKWebView? {
    guard let root else { return nil }
    var best: (view: WKWebView, distance: Double)?
    func visit(_ view: NSView) {
      if let webView = view as? WKWebView, !webView.isHidden {
        let origin = webView.convert(.zero, to: root)
        let viewTop = root.bounds.height - origin.y - webView.bounds.height
        let distance = pow(origin.x - x, 2) + pow(viewTop - top, 2)
        if distance < (best?.distance ?? .greatestFiniteMagnitude) {
          best = (webView, distance)
        }
      }
      view.subviews.forEach(visit)
    }
    visit(root)
    return best?.view
  }

  private static func center(of value: Any?, in webView: WKWebView) -> NSPoint? {
    guard let rect = value as? [String: Any] else { return nil }
    let x = ((rect["left"] as? NSNumber)?.doubleValue ?? 0)
      + ((rect["width"] as? NSNumber)?.doubleValue ?? 0) / 2
    let top = (rect["top"] as? NSNumber)?.doubleValue ?? 0
    let height = (rect["height"] as? NSNumber)?.doubleValue ?? 0
    return NSPoint(x: x, y: webView.bounds.height - top - height / 2)
  }

  private static func sendMouse(_ type: NSEvent.EventType, at point: NSPoint, to webView: WKWebView) {
    guard
      let window = webView.window,
      let event = NSEvent.mouseEvent(
        with: type,
        location: webView.convert(point, to: nil),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: type == .leftMouseUp || type == .leftMouseDown ? 1 : 0,
        pressure: type == .leftMouseDown || type == .leftMouseDragged ? 1 : 0
      )
    else { return }
    switch type {
    case .leftMouseDown: webView.mouseDown(with: event)
    case .leftMouseUp: webView.mouseUp(with: event)
    case .leftMouseDragged: webView.mouseDragged(with: event)
    default: webView.mouseMoved(with: event)
    }
  }

  private static func sendDrag(
    from source: NSPoint,
    to target: NSPoint,
    in webView: WKWebView,
    step: Int = 0,
    result: @escaping FlutterResult
  ) {
    let motionSteps = 8
    if step == 0 {
      sendMouse(.mouseMoved, at: source, to: webView)
      sendMouse(.leftMouseDown, at: source, to: webView)
    } else if step <= motionSteps {
      let progress = CGFloat(step) / CGFloat(motionSteps)
      sendMouse(
        .leftMouseDragged,
        at: NSPoint(
          x: source.x + (target.x - source.x) * progress,
          y: source.y + (target.y - source.y) * progress
        ),
        to: webView
      )
    } else {
      sendMouse(.leftMouseUp, at: target, to: webView)
      result(nil)
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
      sendDrag(
        from: source,
        to: target,
        in: webView,
        step: step + 1,
        result: result
      )
    }
  }

  private static func sendText(_ text: String, to webView: WKWebView) {
    for character in text {
      sendKey(String(character), code: 0, modifiers: [], to: webView)
    }
  }

  private static func sendNamedKey(_ key: String, to webView: WKWebView) {
    let values: [String: (String, UInt16)] = [
      "Enter": ("\r", 36), "Tab": ("\t", 48), "Escape": ("\u{1b}", 53),
      "Backspace": ("\u{8}", 51), "Delete": ("\u{7f}", 117),
      "Home": (String(UnicodeScalar(NSHomeFunctionKey)!), 115),
      "End": (String(UnicodeScalar(NSEndFunctionKey)!), 119),
      "ArrowLeft": (String(UnicodeScalar(NSLeftArrowFunctionKey)!), 123),
      "ArrowRight": (String(UnicodeScalar(NSRightArrowFunctionKey)!), 124),
      "ArrowDown": (String(UnicodeScalar(NSDownArrowFunctionKey)!), 125),
      "ArrowUp": (String(UnicodeScalar(NSUpArrowFunctionKey)!), 126),
    ]
    let value = values[key] ?? (key, 0)
    sendKey(value.0, code: value.1, modifiers: [], to: webView)
  }

  private static func sendKey(
    _ characters: String,
    code: UInt16,
    modifiers: NSEvent.ModifierFlags,
    to webView: WKWebView
  ) {
    guard let window = webView.window else { return }
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      guard let event = NSEvent.keyEvent(
        with: type,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: code
      ) else { continue }
      if type == .keyDown { webView.keyDown(with: event) } else { webView.keyUp(with: event) }
    }
  }
}
