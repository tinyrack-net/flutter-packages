import 'dart:async';

import 'package:browsewell/browsewell_platform_interface.dart';
import 'package:browsewell/src/browsewell_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Method-channel implementation shared by the desktop plugins.
final class MethodChannelBrowsewell extends BrowsewellPlatform {
  /// Creates a method-channel adapter.
  MethodChannelBrowsewell() {
    eventChannel.receiveBroadcastStream().listen(_onEvent);
  }

  /// Native command channel.
  @visibleForTesting
  final methodChannel = const MethodChannel('net.tinyrack.browsewell/methods');

  /// Native event channel.
  @visibleForTesting
  final eventChannel = const EventChannel('net.tinyrack.browsewell/events');

  final Map<String, StreamController<BrowsewellEvent>> _events =
      <String, StreamController<BrowsewellEvent>>{};

  @override
  Future<BrowsewellCreateResult> create(BrowsewellCreateRequest request) async {
    final value = await methodChannel.invokeMapMethod<String, Object?>(
      'create',
      request.toJson(),
    );
    if (value == null) throw const FormatException('Missing create result.');
    return BrowsewellCreateResult.fromJson(value);
  }

  @override
  Future<Object?> execute(String id, BrowsewellCommand command) =>
      methodChannel.invokeMethod<Object?>('execute', <String, Object?>{
        'id': id,
        'command': command.toJson(),
      });

  @override
  Stream<BrowsewellEvent> events(String id) => _events
      .putIfAbsent(id, StreamController<BrowsewellEvent>.broadcast)
      .stream;

  @override
  Future<void> setViewport(
    String id, {
    required Rect rect,
    required bool visible,
  }) => methodChannel.invokeMethod<void>('setViewport', <String, Object?>{
    'id': id,
    'left': rect.left,
    'top': rect.top,
    'width': rect.width,
    'height': rect.height,
    'visible': visible,
  });

  @override
  Future<void> disposeBrowser(String id) async {
    await methodChannel.invokeMethod<void>('dispose', <String, Object?>{
      'id': id,
    });
    await _events.remove(id)?.close();
  }

  void _onEvent(Object? raw) {
    if (raw is! Map<Object?, Object?>) return;
    final event = BrowsewellEvent.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    _events[event.id]?.add(event);
  }
}
