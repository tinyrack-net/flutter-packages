import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:browsewell/browsewell_platform_interface.dart';
import 'package:browsewell/src/browsewell_models.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_all/webview_all.dart';

/// Native-webview implementation shared by Browsewell's desktop targets.
final class WebviewAllBrowsewellPlatform extends BrowsewellPlatform {
  /// Creates the desktop backend.
  WebviewAllBrowsewellPlatform({bool? captureFlutterTexture})
    : _captureFlutterTexture = captureFlutterTexture ?? Platform.isWindows;

  static const _automation = MethodChannel(
    'net.tinyrack.browsewell/automation',
  );

  final Map<String, _Browser> _browsers = <String, _Browser>{};
  final bool _captureFlutterTexture;
  var _nextId = 1;

  @override
  Future<BrowsewellCreateResult> create(BrowsewellCreateRequest request) async {
    final id = 'browsewell-${_nextId++}';
    final events = StreamController<BrowsewellEvent>.broadcast();
    final logs = <BrowsewellLogEntry>[];
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setOnConsoleMessage((message) {
      _appendLog(
        logs,
        request.policy.maxLogEntries,
        BrowsewellLogEntry(
          level: message.level.name,
          message: message.message,
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
        ),
      );
    });
    await controller.setOnJavaScriptAlertDialog((dialog) async {
      _appendLog(
        logs,
        request.policy.maxLogEntries,
        BrowsewellLogEntry(
          level: 'dialog',
          message: 'alert accepted: ${dialog.message}',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
        ),
      );
    });
    await controller.setOnJavaScriptConfirmDialog((dialog) async {
      _appendLog(
        logs,
        request.policy.maxLogEntries,
        BrowsewellLogEntry(
          level: 'dialog',
          message: 'confirm rejected: ${dialog.message}',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
        ),
      );
      return false;
    });
    await controller.setOnJavaScriptTextInputDialog((dialog) async {
      _appendLog(
        logs,
        request.policy.maxLogEntries,
        BrowsewellLogEntry(
          level: 'dialog',
          message: 'prompt rejected: ${dialog.message}',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
        ),
      );
      return '';
    });
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (navigation) =>
            request.policy.allowedSchemes.contains(
              Uri.parse(navigation.url).scheme,
            )
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageStarted: (url) => events.add(
          BrowsewellEvent(
            id: id,
            type: 'loadStart',
            url: Uri.tryParse(url),
          ),
        ),
        onPageFinished: (url) async {
          events.add(
            BrowsewellEvent(
              id: id,
              type: 'loadEnd',
              url: Uri.tryParse(url),
              title: await controller.getTitle(),
            ),
          );
        },
        onWebResourceError: (error) => events.add(
          BrowsewellEvent(
            id: id,
            type: 'loadError',
            message: error.description,
          ),
        ),
      ),
    );
    _browsers[id] = _Browser(
      controller: controller,
      events: events,
      logs: logs,
      policy: request.policy,
    );
    await controller.loadRequest(request.initialUrl);
    return BrowsewellCreateResult(
      id: id,
      capabilities: BrowsewellCapabilities.desktop,
    );
  }

  @override
  Widget buildView(String id) {
    final browser = _browser(id);
    return ValueListenableBuilder<Size?>(
      valueListenable: browser.viewportSize,
      builder: (context, size, child) {
        if (size == null) {
          return KeyedSubtree(
            key: ValueKey<String>('$id-viewport'),
            child: child!,
          );
        }
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: ValueKey<String>('$id-viewport'),
            width: size.width,
            height: size.height,
            child: child,
          ),
        );
      },
      child: RepaintBoundary(
        key: browser.captureKey,
        child: WebViewWidget(controller: browser.controller),
      ),
    );
  }

  @override
  Stream<BrowsewellEvent> events(String id) => _browser(id).events.stream;

  @override
  Future<void> setViewport(
    String id, {
    required Rect rect,
    required bool visible,
  }) {
    _browser(id).viewportRect = rect;
    return _automation.invokeMethod<void>('setViewport', <String, Object?>{
      'id': id,
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
      'visible': visible,
    });
  }

  @override
  Future<void> disposeBrowser(String id) async {
    final browser = _browsers.remove(id);
    if (browser != null) {
      browser.viewportSize.dispose();
      await browser.events.close();
    }
  }

  @override
  Future<Object?> execute(String id, BrowsewellCommand command) async {
    final browser = _browser(id);
    final arguments = command.arguments;
    switch (command.name) {
      case 'navigate':
        await browser.controller.loadRequest(
          Uri.parse(arguments['url']! as String),
        );
      case 'back':
        await browser.controller.goBack();
      case 'forward':
        await browser.controller.goForward();
      case 'reload':
        await browser.controller.reload();
      case 'resize':
        final width = arguments['width'];
        final height = arguments['height'];
        if (width is! num || height is! num || width <= 0 || height <= 0) {
          throw const BrowsewellException(
            BrowsewellErrorCode.denied,
            'Viewport dimensions must be positive numbers.',
          );
        }
        browser.viewportSize.value = Size(width.toDouble(), height.toDouble());
      case 'snapshot':
        final snapshot = await _run(browser, _snapshotScript);
        if (snapshot is! Map<Object?, Object?> ||
            snapshot['generation'] is! int) {
          throw const BrowsewellException(
            BrowsewellErrorCode.internal,
            'The page returned an invalid snapshot.',
          );
        }
        browser.snapshotGeneration = snapshot['generation']! as int;
        return snapshot;
      case 'screenshot':
        final rawBytes = _captureFlutterTexture
            ? await _captureFlutter(
                browser,
                fullPage: arguments['fullPage'] == true,
              )
            : await _automation.invokeMethod<Object?>(
                'screenshot',
                _nativeArguments(id, browser, arguments),
              );
        final bytes = browsewellBytes(rawBytes);
        if (bytes.length > browser.policy.maxScreenshotBytes) {
          throw const BrowsewellException(
            BrowsewellErrorCode.denied,
            'The screenshot exceeds the configured result limit.',
          );
        }
        return bytes;
      case 'logs':
        await _collectNetworkLogs(browser);
        return _encodedLogs(browser, arguments['maxEntries']! as int);
      case 'wait':
        await _wait(browser, arguments);
      case 'click':
      case 'hover':
        _ensureCurrentRef(browser, arguments['ref']! as String);
        await _automation.invokeMethod<void>(
          command.name,
          _nativeArguments(id, browser, <String, Object?>{
            'rect': await _rect(browser, arguments['ref']! as String),
          }),
        );
      case 'fill':
        _ensureCurrentRef(browser, arguments['ref']! as String);
        await _focus(browser, arguments['ref']! as String);
        await _type(id, arguments['value']! as String, replace: true);
      case 'type':
        final ref = arguments['ref'] as String?;
        if (ref != null) {
          _ensureCurrentRef(browser, ref);
          await _focus(browser, ref);
        }
        await _type(id, arguments['text']! as String, replace: false);
      case 'keypress':
        final ref = arguments['ref'] as String?;
        if (ref != null) {
          _ensureCurrentRef(browser, ref);
          await _focus(browser, ref);
        }
        await _automation.invokeMethod<void>(
          'keypress',
          _nativeArguments(id, browser, <String, Object?>{
            'key': arguments['key'],
          }),
        );
      case 'select':
        _ensureCurrentRef(browser, arguments['ref']! as String);
        await _focus(browser, arguments['ref']! as String);
        await _automation.invokeMethod<void>(
          'select',
          _nativeArguments(id, browser, <String, Object?>{
            'value': arguments['value'],
          }),
        );
      case 'drag':
        _ensureCurrentRef(browser, arguments['sourceRef']! as String);
        _ensureCurrentRef(browser, arguments['targetRef']! as String);
        await _automation.invokeMethod<void>(
          'drag',
          _nativeArguments(id, browser, <String, Object?>{
            'source': await _rect(browser, arguments['sourceRef']! as String),
            'target': await _rect(browser, arguments['targetRef']! as String),
          }),
        );
      case 'upload':
        _ensureCurrentRef(browser, arguments['ref']! as String);
        await _focus(browser, arguments['ref']! as String);
        await _automation.invokeMethod<void>(
          'upload',
          _nativeArguments(id, browser, <String, Object?>{
            'filePaths': arguments['filePaths'],
          }),
        );
      case 'scroll':
        final ref = arguments['ref'] as String?;
        if (ref != null) _ensureCurrentRef(browser, ref);
        await _automation.invokeMethod<void>(
          'scroll',
          _nativeArguments(id, browser, arguments),
        );
      case 'evaluate':
        final ref = arguments['ref'] as String?;
        final target = ref == null
            ? 'undefined'
            : 'window.__browsewellRefs?.[${jsonEncode(ref)}]';
        if (ref != null) _ensureCurrentRef(browser, ref);
        final value = await _run(
          browser,
          '(() => (${arguments['function']})($target))()',
        );
        if (utf8.encode(jsonEncode(value)).length >
            browser.policy.maxEvaluateResultBytes) {
          throw const BrowsewellException(
            BrowsewellErrorCode.denied,
            'The evaluation result exceeds the configured result limit.',
          );
        }
        return value;
      default:
        throw BrowsewellException(
          BrowsewellErrorCode.unsupported,
          'Unknown command ${command.name}.',
        );
    }
    return null;
  }

  _Browser _browser(String id) =>
      _browsers[id] ??
      (throw const BrowsewellException(
        BrowsewellErrorCode.tabNotFound,
        'Browser does not exist.',
      ));

  Future<Object?> _run(_Browser browser, String source) async {
    final value = await browser.controller.runJavaScriptReturningResult(
      '(() => { const value = ($source); return JSON.stringify( '
      'value === undefined ? null : value); })()',
    );
    if (value is! String) return value;
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  List<Map<String, Object?>> _encodedLogs(_Browser browser, int maximum) =>
      browser.logs
          .skip(
            browser.logs.length > maximum ? browser.logs.length - maximum : 0,
          )
          .map(
            (entry) => <String, Object?>{
              'level': entry.level,
              'message': entry.message,
              'timestampMicros': entry.timestampMicros,
            },
          )
          .toList(growable: false);

  Future<void> _focus(_Browser browser, String ref) async {
    await _rect(browser, ref);
    final status = await _run(
      browser,
      '(() => { const element = window.__browsewellRefs?.['
      '${jsonEncode(ref)}]; if (!element?.isConnected) return "stale_ref"; '
      'element.focus(); return "ok"; })()',
    );
    if (status == 'stale_ref') _throwStaleRef();
  }

  void _ensureCurrentRef(_Browser browser, String ref) {
    final match = RegExp(r'^@(\d+):\d+$').firstMatch(ref);
    if (match == null ||
        int.tryParse(match.group(1)!) != browser.snapshotGeneration) {
      _throwStaleRef();
    }
  }

  Future<Map<String, Object?>> _rect(_Browser browser, String ref) async {
    final raw = await _run(
      browser,
      '(() => { const element = window.__browsewellRefs?.['
      '${jsonEncode(ref)}]; if (!element?.isConnected) '
      'return {error:"stale_ref"}; '
      'const rect = element.getBoundingClientRect(); '
      'const style = getComputedStyle(element); '
      'if (element.disabled || rect.width <= 0 || rect.height <= 0 || '
      'style.display === "none" || style.visibility === "hidden" || '
      'style.pointerEvents === "none") return {error:"denied"}; '
      'return {left: rect.left, top: rect.top, width: rect.width, '
      'height: rect.height}; })()',
    );
    if (raw is! Map<Object?, Object?>) {
      throw const BrowsewellException(
        BrowsewellErrorCode.internal,
        'Invalid element bounds.',
      );
    }
    if (raw['error'] == 'stale_ref') _throwStaleRef();
    if (raw['error'] == 'denied') {
      throw const BrowsewellException(
        BrowsewellErrorCode.denied,
        'The element is not actionable.',
      );
    }
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Never _throwStaleRef() => throw const BrowsewellException(
    BrowsewellErrorCode.staleRef,
    'The element reference is stale.',
  );

  Future<void> _type(String id, String value, {required bool replace}) =>
      _automation.invokeMethod<void>(
        'type',
        _nativeArguments(id, _browser(id), <String, Object?>{
          'text': value,
          'replace': replace,
        }),
      );

  Map<String, Object?> _nativeArguments(
    String id,
    _Browser browser,
    Map<String, Object?> arguments,
  ) => <String, Object?>{
    'id': id,
    'viewportLeft': browser.viewportRect.left,
    'viewportTop': browser.viewportRect.top,
    'devicePixelRatio':
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio,
    ...arguments,
  };

  Future<void> _wait(_Browser browser, Map<String, Object?> arguments) async {
    final deadline = DateTime.now().add(
      Duration(milliseconds: arguments['timeoutMs']! as int),
    );
    while (DateTime.now().isBefore(deadline)) {
      final script = arguments['text'] != null
          ? 'document.body?.innerText.includes('
                '${jsonEncode(arguments['text'])}) ?? false'
          : 'location.href.includes(${jsonEncode(arguments['url'])})';
      try {
        if (await _run(browser, script) == true) return;
      } on PlatformException {
        // WKWebView rejects evaluation briefly while a navigation is
        // committing. A wait condition spans that transient page state.
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw const BrowsewellException(
      BrowsewellErrorCode.timeout,
      'Wait condition timed out.',
    );
  }

  Future<void> _collectNetworkLogs(_Browser browser) async {
    final raw = await _run(
      browser,
      "performance.getEntriesByType('resource').map((entry) => "
      '({name: entry.name, duration: entry.duration}))',
    );
    if (raw is! List<Object?>) return;
    for (final value in raw.whereType<Map<Object?, Object?>>()) {
      final name = value['name'];
      if (name is! String || !browser.networkEntries.add(name)) continue;
      _appendLog(
        browser.logs,
        browser.maxLogEntries,
        BrowsewellLogEntry(
          level: 'network',
          message: '$name ${value['duration'] ?? 0}ms',
          timestampMicros: DateTime.now().microsecondsSinceEpoch,
        ),
      );
    }
  }

  Future<Uint8List> _captureFlutter(
    _Browser browser, {
    required bool fullPage,
  }) async {
    final boundary = browser.captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
      throw const BrowsewellException(
        BrowsewellErrorCode.internal,
        'The browser view is not attached.',
      );
    }
    if (!fullPage) {
      return _png(await boundary.toImage());
    }

    final metrics = await _run(
      browser,
      '({height: document.documentElement.scrollHeight, '
      'x: scrollX, y: scrollY})',
    );
    if (metrics is! Map<Object?, Object?>) {
      throw const BrowsewellException(
        BrowsewellErrorCode.internal,
        'The document dimensions are unavailable.',
      );
    }
    final rawHeight = metrics['height'];
    final rawX = metrics['x'];
    final rawY = metrics['y'];
    if (rawHeight is! num || rawX is! num || rawY is! num) {
      throw const BrowsewellException(
        BrowsewellErrorCode.internal,
        'The document dimensions are invalid.',
      );
    }
    final height = rawHeight.ceil();
    final originalX = rawX.toDouble();
    final originalY = rawY.toDouble();
    final viewportHeight = boundary.size.height.ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var y = 0; y < height; y += viewportHeight) {
      await _run(browser, 'scrollTo(0, $y)');
      await Future<void>.delayed(const Duration(milliseconds: 32));
      final actual = await _run(browser, 'scrollY');
      if (actual is! num) {
        throw const BrowsewellException(
          BrowsewellErrorCode.internal,
          'The document scroll position is invalid.',
        );
      }
      final image = await boundary.toImage();
      canvas.drawImage(image, Offset(0, actual.toDouble()), Paint());
      image.dispose();
    }
    await _run(browser, 'scrollTo($originalX, $originalY)');
    final image = await recorder.endRecording().toImage(
      boundary.size.width.ceil(),
      height,
    );
    final bytes = await _png(image);
    image.dispose();
    return bytes;
  }

  Future<Uint8List> _png(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const BrowsewellException(
        BrowsewellErrorCode.internal,
        'PNG encoding failed.',
      );
    }
    return data.buffer.asUint8List();
  }
}

void _appendLog(
  List<BrowsewellLogEntry> logs,
  int maximum,
  BrowsewellLogEntry entry,
) {
  logs.add(entry);
  if (logs.length > maximum) logs.removeAt(0);
}

final class _Browser {
  _Browser({
    required this.controller,
    required this.events,
    required this.logs,
    required this.policy,
  });

  final WebViewController controller;
  final StreamController<BrowsewellEvent> events;
  final List<BrowsewellLogEntry> logs;
  final BrowsewellPolicy policy;
  int snapshotGeneration = 0;
  final Set<String> networkEntries = <String>{};
  final GlobalKey captureKey = GlobalKey();
  final ValueNotifier<Size?> viewportSize = ValueNotifier<Size?>(null);
  Rect viewportRect = Rect.zero;

  int get maxLogEntries => policy.maxLogEntries;
}

const _snapshotScript = r'''
(() => {
  const generation = (window.__browsewellGeneration || 0) + 1;
  const refs = Object.create(null);
  let nextRef = 1;
  const visit = element => {
    if (!(element instanceof Element)) return null;
    const tag = element.tagName.toLowerCase();
    const interactive = ['a','button','input','select','textarea'].includes(tag) ||
      element.tabIndex >= 0 || element.getAttribute('role') === 'button';
    const node = {
      role: element.getAttribute('role') || ({a:'link',button:'button',input:'textbox',select:'combobox',textarea:'textbox'}[tag] || 'generic'),
      name: element.getAttribute('aria-label') || element.innerText?.trim() || element.value || '',
      children: Array.from(element.children).map(visit).filter(Boolean),
    };
    if (interactive) {
      const ref = `@${generation}:${nextRef++}`;
      refs[ref] = element;
      node.ref = ref;
      if ('value' in element) node.value = element.value;
    }
    return node;
  };
  window.__browsewellGeneration = generation;
  window.__browsewellRefs = refs;
  return {generation, document: visit(document.documentElement)};
})()''';
