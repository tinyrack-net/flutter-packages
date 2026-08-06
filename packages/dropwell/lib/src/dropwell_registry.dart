import 'dart:async';
import 'dart:ui';

import 'package:dropwell/src/dropwell_drag_event.dart';
import 'package:dropwell/src/dropwell_file.dart';
import 'package:dropwell/src/dropwell_geometry.dart';
import 'package:dropwell/src/dropwell_platform.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

/// One drop target known to the registry.
///
/// The registry never touches a widget or an element; it asks a target for a
/// physical rectangle and calls back. That keeps hit testing and event routing
/// testable without a render tree.
abstract interface class DropwellTarget {
  /// Current bounds in physical pixels, or `null` when the target is not laid
  /// out or is currently refusing drops.
  Rect? get physicalBounds;

  /// Reports whether a drag is currently hovering this target.
  void onHoverChanged({required bool hovering});

  /// Delivers a completed drop.
  Future<void> onDrop(List<DropwellFile> files);
}

/// Routes native drag events to the registered [DropwellTarget]s.
///
/// A single registry owns the native subscription and the published-region
/// list, so platform code receives one coherent view of the app no matter how
/// many regions are mounted.
final class DropwellRegistry {
  /// Creates a registry over the given platform implementation.
  DropwellRegistry(this._platform) {
    _subscription = _platform.dragEvents.listen(handleEvent);
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  static DropwellRegistry? _instance;

  /// Lazily created registry over [DropwellPlatform.instance].
  // A constructor cannot express "reuse the one that already exists", which is
  // the whole point: one registry owns the single native subscription.
  // ignore: prefer_constructors_over_static_methods
  static DropwellRegistry get instance =>
      _instance ??= DropwellRegistry(DropwellPlatform.instance);

  /// Discards the shared registry so a test can build a fresh one.
  @visibleForTesting
  static Future<void> resetInstance() async {
    await _instance?.dispose();
    _instance = null;
  }

  final DropwellPlatform _platform;
  final List<DropwellTarget> _targets = <DropwellTarget>[];
  late final StreamSubscription<DropwellDragEvent> _subscription;

  List<Rect> _published = const <Rect>[];
  DropwellTarget? _hovered;
  bool _disposed = false;

  /// Targets in registration order; later targets sit on top.
  @visibleForTesting
  List<DropwellTarget> get targets =>
      List<DropwellTarget>.unmodifiable(_targets);

  /// Regions most recently sent to platform code.
  @visibleForTesting
  List<Rect> get publishedRegions => _published;

  /// Adds [target].
  void register(DropwellTarget target) {
    _targets.add(target);
    _publishAfterFrame();
  }

  /// Removes [target].
  void unregister(DropwellTarget target) {
    _targets.remove(target);
    if (identical(_hovered, target)) _hovered = null;
    _publishAfterFrame();
  }

  /// Sends the current bounds to platform code when they changed.
  ///
  /// Called after layout on every frame. Bounds move for reasons no widget can
  /// announce — a scroll, an animation, a window resize, a route transition —
  /// so the registry re-reads them rather than trusting a notification, and
  /// suppresses the message when nothing moved.
  @visibleForTesting
  Future<void> publishIfChanged() async {
    final regions = List<Rect>.unmodifiable(
      _targets.map((target) => target.physicalBounds).whereType<Rect>(),
    );
    if (_listEquals(regions, _published)) return;
    _published = regions;
    await _platform.publishDropRegions(regions);
  }

  /// Routes one native drag event.
  @visibleForTesting
  Future<void> handleEvent(DropwellDragEvent event) async {
    if (event.phase == DropwellDragPhase.leave) {
      _setHovered(null);
      return;
    }
    final target = _targetAt(event.physicalPosition);
    if (event.phase != DropwellDragPhase.perform) {
      _setHovered(target);
      return;
    }
    _setHovered(null);
    // A drop outside every published region is not an error: the operating
    // system can deliver one in the frame after a region moved away.
    if (target == null) return;
    await target.onDrop(event.files);
  }

  /// Cancels the native subscription and forgets every target.
  Future<void> dispose() async {
    _disposed = true;
    _targets.clear();
    _hovered = null;
    await _subscription.cancel();
  }

  void _onFrame(Duration timeStamp) {
    if (_disposed) return;
    unawaited(publishIfChanged());
  }

  /// Publishes once the frame that mounted or unmounted a region has laid out.
  ///
  /// The per-frame callback alone is not enough: an app that mounts a region
  /// and then goes idle produces no further frame, and the operating system
  /// would refuse a drop the app was ready to accept.
  void _publishAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      unawaited(publishIfChanged());
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  DropwellTarget? _targetAt(Offset physicalPosition) {
    final live = _targets
        .where((target) => target.physicalBounds != null)
        .toList(growable: false);
    final index = DropwellGeometry.topmostRegionAt(
      live.map((target) => target.physicalBounds!).toList(growable: false),
      physicalPosition,
    );
    return index == null ? null : live[index];
  }

  void _setHovered(DropwellTarget? target) {
    if (identical(_hovered, target)) return;
    _hovered?.onHoverChanged(hovering: false);
    _hovered = target;
    target?.onHoverChanged(hovering: true);
  }

  static bool _listEquals(List<Rect> left, List<Rect> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
