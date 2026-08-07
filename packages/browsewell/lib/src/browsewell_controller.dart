import 'dart:async';
import 'package:browsewell/browsewell_platform_interface.dart';
import 'package:browsewell/src/browsewell_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Controls one native Browsewell instance.
final class BrowsewellController extends ValueNotifier<BrowsewellState> {
  BrowsewellController._({
    required this.id,
    required this.capabilities,
    required this._policy,
    required Uri initialUrl,
    required BrowsewellPlatform platform,
  }) : _platform = platform,
       super(
         BrowsewellState(
           url: initialUrl,
           title: '',
           loadState: BrowsewellLoadState.idle,
         ),
       ) {
    _subscription = platform.events(id).listen(_onEvent);
  }

  /// Creates one browser using an explicit persistent profile.
  static Future<BrowsewellController> create({
    required BrowsewellProfile profile,
    Uri? initialUrl,
    BrowsewellPolicy policy = const BrowsewellPolicy(),
  }) async {
    final url = initialUrl ?? Uri.parse('about:blank');
    _validateUrl(url, policy);
    final platform = BrowsewellPlatform.instance;
    final result = await platform.create(
      BrowsewellCreateRequest(
        profile: profile,
        initialUrl: url,
        policy: policy,
      ),
    );
    return BrowsewellController._(
      id: result.id,
      capabilities: result.capabilities,
      policy: policy,
      initialUrl: url,
      platform: platform,
    );
  }

  /// Native identity.
  final String id;

  /// Backend capabilities.
  final BrowsewellCapabilities capabilities;

  final BrowsewellPolicy _policy;
  final BrowsewellPlatform _platform;
  late final StreamSubscription<BrowsewellEvent> _subscription;
  bool _disposed = false;

  /// Navigates to an allowed URL.
  Future<void> navigate(Uri url) async {
    _validateUrl(url, _policy);
    await _run('navigate', <String, Object?>{'url': url.toString()});
  }

  /// Navigates backward.
  Future<void> back() => _runVoid('back');

  /// Navigates forward.
  Future<void> forward() => _runVoid('forward');

  /// Reloads the page.
  Future<void> reload() => _runVoid('reload');

  /// Resizes the browser viewport.
  Future<void> resize(Size size) => _runVoid('resize', <String, Object?>{
    'width': size.width,
    'height': size.height,
  });

  /// Returns an accessibility snapshot.
  Future<BrowsewellSnapshot> snapshot() async =>
      BrowsewellSnapshot.fromJson(_stringMap(await _run('snapshot')));

  /// Captures a PNG.
  Future<Uint8List> screenshot({bool fullPage = false}) async =>
      browsewellBytes(
        await _run('screenshot', <String, Object?>{'fullPage': fullPage}),
      );

  /// Returns recent console and network log entries.
  Future<List<BrowsewellLogEntry>> logs({int? maxEntries}) async {
    final count = maxEntries ?? _policy.maxLogEntries;
    final raw = await _run('logs', <String, Object?>{'maxEntries': count});
    if (raw is! List<Object?>) {
      throw const FormatException('Invalid logs result.');
    }
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((item) => BrowsewellLogEntry.fromJson(_stringMap(item)))
        .toList(growable: false);
  }

  /// Waits for text or a URL fragment.
  Future<void> waitFor({String? text, String? url, Duration? timeout}) {
    if ((text == null) == (url == null)) {
      throw ArgumentError('Exactly one of text or url is required.');
    }
    return _runVoid('wait', <String, Object?>{
      'text': ?text,
      'url': ?url,
      'timeoutMs': (timeout ?? const Duration(seconds: 10)).inMilliseconds,
    });
  }

  /// Clicks a snapshot ref using trusted native input.
  Future<void> click(String ref) => _refCommand('click', ref);

  /// Replaces an input value.
  Future<void> fill(String ref, String value) =>
      _refCommand('fill', ref, <String, Object?>{'value': value});

  /// Types text into a ref or the focused element.
  Future<void> type(String text, {String? ref}) => _runVoid(
    'type',
    <String, Object?>{'ref': ?ref, 'text': text},
  );

  /// Presses a key.
  Future<void> keypress(String key, {String? ref}) => _runVoid(
    'keypress',
    <String, Object?>{'ref': ?ref, 'key': key},
  );

  /// Hovers a ref.
  Future<void> hover(String ref) => _refCommand('hover', ref);

  /// Selects one native option.
  Future<void> select(String ref, String value) =>
      _refCommand('select', ref, <String, Object?>{'value': value});

  /// Drags one ref onto another.
  Future<void> drag(String sourceRef, String targetRef) => _runVoid(
    'drag',
    <String, Object?>{'sourceRef': sourceRef, 'targetRef': targetRef},
  );

  /// Completes a native file input with consumer-validated paths.
  Future<void> upload(String ref, List<String> filePaths) =>
      _refCommand('upload', ref, <String, Object?>{'filePaths': filePaths});

  /// Dispatches trusted wheel input.
  Future<void> scroll({
    required double deltaX,
    required double deltaY,
    String? ref,
  }) => _runVoid('scroll', <String, Object?>{
    'ref': ?ref,
    'deltaX': deltaX,
    'deltaY': deltaY,
  });

  /// Evaluates a JavaScript function and returns bounded JSON.
  Future<Object?> evaluate(String function, {String? ref}) => _run(
    'evaluate',
    <String, Object?>{'function': function, 'ref': ?ref},
  );

  /// Updates the native overlay geometry.
  Future<void> setViewport(Rect rect, {required bool visible}) =>
      _platform.setViewport(id, rect: rect, visible: visible);

  Future<void> _refCommand(
    String name,
    String ref, [
    Map<String, Object?> extra = const <String, Object?>{},
  ]) => _runVoid(name, <String, Object?>{'ref': ref, ...extra});

  Future<void> _runVoid(
    String name, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    await _run(name, arguments);
  }

  Future<Object?> _run(
    String name, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) {
    if (_disposed) {
      throw StateError('BrowsewellController is disposed.');
    }
    return _platform.execute(id, BrowsewellCommand(name, arguments));
  }

  void _onEvent(BrowsewellEvent event) {
    value = BrowsewellState(
      url: event.url ?? value.url,
      title: event.title ?? value.title,
      loadState: switch (event.type) {
        'loadStart' => BrowsewellLoadState.loading,
        'loadEnd' => BrowsewellLoadState.loaded,
        'loadError' => BrowsewellLoadState.failed,
        _ => value.loadState,
      },
      error: event.type == 'loadError' ? event.message : null,
    );
  }

  /// Releases the native browser and its stream.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription.cancel();
    await _platform.disposeBrowser(id);
    super.dispose();
  }
}

void _validateUrl(Uri url, BrowsewellPolicy policy) {
  if (!policy.allowedSchemes.contains(url.scheme) ||
      (url.scheme == 'about' && url.toString() != 'about:blank')) {
    throw BrowsewellException(
      BrowsewellErrorCode.denied,
      'Navigation to ${url.scheme} is not allowed.',
    );
  }
}

Map<String, Object?> _stringMap(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    throw const FormatException('Expected a map.');
  }
  return raw.map((key, value) => MapEntry(key.toString(), value));
}
