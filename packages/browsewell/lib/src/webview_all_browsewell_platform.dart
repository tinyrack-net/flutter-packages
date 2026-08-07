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
      maxLogEntries: request.policy.maxLogEntries,
    );
    await controller.loadRequest(request.initialUrl);
    return BrowsewellCreateResult(
      id: id,
      capabilities: BrowsewellCapabilities.desktop,
    );
  }

  @override
  Widget buildView(String id) => RepaintBoundary(
    key: _browser(id).captureKey,
    child: WebViewWidget(controller: _browser(id).controller),
  );

  @override
  Stream<BrowsewellEvent> events(String id) => _browser(id).events.stream;

  @override
  Future<void> setViewport(
    String id, {
    required Rect rect,
    required bool visible,
  }) => _automation.invokeMethod<void>('setViewport', <String, Object?>{
    'id': id,
    'left': rect.left,
    'top': rect.top,
    'width': rect.width,
    'height': rect.height,
    'visible': visible,
  });

  @override
  Future<void> disposeBrowser(String id) async {
    final browser = _browsers.remove(id);
    if (browser != null) await browser.events.close();
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
        return null;
      case 'snapshot':
        return _run(browser, _snapshotScript);
      case 'screenshot':
        if (_captureFlutterTexture) {
          return _captureFlutter(
            browser,
            fullPage: arguments['fullPage'] == true,
          );
        }
        return _automation.invokeMethod<Object?>(
          'screenshot',
          <String, Object?>{
            'id': id,
            ...arguments,
          },
        );
      case 'logs':
        await _collectNetworkLogs(browser);
        return _encodedLogs(browser, arguments['maxEntries']! as int);
      case 'wait':
        await _wait(browser, arguments);
      case 'click':
      case 'hover':
        await _automation.invokeMethod<void>(command.name, <String, Object?>{
          'id': id,
          'rect': await _rect(browser, arguments['ref']! as String),
        });
      case 'fill':
        await _focus(browser, arguments['ref']! as String);
        await _type(id, arguments['value']! as String, replace: true);
      case 'type':
        final ref = arguments['ref'] as String?;
        if (ref != null) await _focus(browser, ref);
        await _type(id, arguments['text']! as String, replace: false);
      case 'keypress':
        final ref = arguments['ref'] as String?;
        if (ref != null) await _focus(browser, ref);
        await _automation.invokeMethod<void>('keypress', <String, Object?>{
          'id': id,
          'key': arguments['key'],
        });
      case 'select':
        await _focus(browser, arguments['ref']! as String);
        await _automation.invokeMethod<void>('select', <String, Object?>{
          'id': id,
          'value': arguments['value'],
        });
      case 'drag':
        await _automation.invokeMethod<void>('drag', <String, Object?>{
          'id': id,
          'source': await _rect(browser, arguments['sourceRef']! as String),
          'target': await _rect(browser, arguments['targetRef']! as String),
        });
      case 'upload':
        await _focus(browser, arguments['ref']! as String);
        await _automation.invokeMethod<void>('upload', <String, Object?>{
          'id': id,
          'filePaths': arguments['filePaths'],
        });
      case 'scroll':
        await _automation.invokeMethod<void>('scroll', <String, Object?>{
          'id': id,
          ...arguments,
        });
      case 'evaluate':
        final ref = arguments['ref'] as String?;
        final target = ref == null
            ? 'undefined'
            : 'window.__browsewellRefs?.[${jsonEncode(ref)}]';
        return _run(
          browser,
          '(() => (${arguments['function']})($target))()',
        );
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
    await _run(
      browser,
      '(() => { const element = window.__browsewellRefs?.['
      '${jsonEncode(ref)}]; if (!element) throw new Error("stale_ref"); '
      'element.focus(); })()',
    );
  }

  Future<Map<String, Object?>> _rect(_Browser browser, String ref) async {
    final raw = await _run(
      browser,
      '(() => { const element = window.__browsewellRefs?.['
      '${jsonEncode(ref)}]; if (!element) throw new Error("stale_ref"); '
      'const rect = element.getBoundingClientRect(); return {left: rect.left, '
      'top: rect.top, width: rect.width, height: rect.height}; })()',
    );
    if (raw is! Map<Object?, Object?>) {
      throw const BrowsewellException(
        BrowsewellErrorCode.internal,
        'Invalid element bounds.',
      );
    }
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> _type(String id, String value, {required bool replace}) =>
      _automation.invokeMethod<void>('type', <String, Object?>{
        'id': id,
        'text': value,
        'replace': replace,
      });

  Future<void> _wait(_Browser browser, Map<String, Object?> arguments) async {
    final deadline = DateTime.now().add(
      Duration(milliseconds: arguments['timeoutMs']! as int),
    );
    while (DateTime.now().isBefore(deadline)) {
      final script = arguments['text'] != null
          ? 'document.body?.innerText.includes('
                '${jsonEncode(arguments['text'])}) ?? false'
          : 'location.href.includes(${jsonEncode(arguments['url'])})';
      if (await _run(browser, script) == true) return;
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
    required this.maxLogEntries,
  });

  final WebViewController controller;
  final StreamController<BrowsewellEvent> events;
  final List<BrowsewellLogEntry> logs;
  final int maxLogEntries;
  final Set<String> networkEntries = <String>{};
  final GlobalKey captureKey = GlobalKey();
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
