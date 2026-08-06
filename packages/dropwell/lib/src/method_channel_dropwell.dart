import 'dart:async';

import 'package:dropwell/src/dropwell_codec.dart';
import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';
import 'package:dropwell/src/dropwell_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platforms whose native drop implementation is complete.
///
/// This set grows one platform at a time as each native implementation lands
/// with its conformance evidence. Listing a platform here that cannot actually
/// deliver a drop is, by definition, the one defect this package cannot
/// tolerate: consumers build their entire drop affordance on this answer.
const Set<TargetPlatform> kDropCapablePlatforms = <TargetPlatform>{
  TargetPlatform.linux,
  TargetPlatform.windows,
};

/// Platforms whose native clipboard implementation is complete.
const Set<TargetPlatform> kClipboardCapablePlatforms = <TargetPlatform>{
  TargetPlatform.linux,
  TargetPlatform.windows,
};

/// Method-channel implementation shared by every non-web platform.
base class MethodChannelDropwell extends DropwellPlatform {
  /// Creates the implementation and starts listening for native drag events.
  MethodChannelDropwell({
    @visibleForTesting MethodChannel? channel,
    @visibleForTesting Set<TargetPlatform>? dropPlatforms,
    @visibleForTesting Set<TargetPlatform>? clipboardPlatforms,
  }) : channel = channel ?? const MethodChannel('dropwell'),
       _dropPlatforms = dropPlatforms ?? kDropCapablePlatforms,
       _clipboardPlatforms = clipboardPlatforms ?? kClipboardCapablePlatforms {
    this.channel.setMethodCallHandler(_handleNativeCall);
  }

  /// Channel shared with platform code.
  @visibleForTesting
  final MethodChannel channel;

  final Set<TargetPlatform> _dropPlatforms;
  final Set<TargetPlatform> _clipboardPlatforms;
  final StreamController<DropwellDragEvent> _dragEvents =
      StreamController<DropwellDragEvent>.broadcast();

  @override
  bool get supportsDrop => _dropPlatforms.contains(defaultTargetPlatform);

  @override
  bool get supportsClipboardFiles =>
      _clipboardPlatforms.contains(defaultTargetPlatform);

  @override
  Stream<DropwellDragEvent> get dragEvents => _dragEvents.stream;

  @override
  Future<List<DropwellFile>> readClipboardFiles() async {
    if (!supportsClipboardFiles) return const <DropwellFile>[];
    final payload = await channel.invokeMethod<List<Object?>>(
      'readClipboardFiles',
    );
    return DropwellCodec.decodeFiles(payload);
  }

  @override
  Future<void> publishDropRegions(List<Rect> physicalRegions) async {
    if (!supportsDrop) return;
    await channel.invokeMethod<void>(
      'publishDropRegions',
      DropwellCodec.encodeRegions(physicalRegions),
    );
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'drag') {
      throw MissingPluginException('dropwell got unknown call ${call.method}');
    }
    _dragEvents.add(DropwellCodec.decodeDragEvent(call.arguments));
  }
}
