import 'package:dropwell/src/dropwell_file.dart';
import 'package:dropwell/src/dropwell_geometry.dart';
import 'package:dropwell/src/dropwell_registry.dart';
import 'package:flutter/widgets.dart';

/// Accepts files dropped onto [child] from outside the application.
///
/// The region publishes its bounds to platform code so the operating system
/// can answer its own synchronous "will you accept this?" question. Mounting a
/// region on a platform whose `DropwellPlatform.supportsDrop` is `false` is
/// harmless: it renders [child] and never fires.
class DropwellRegion extends StatefulWidget {
  /// Creates a drop region.
  const DropwellRegion({
    required this.onDrop,
    required this.child,
    this.onHoverChanged,
    this.enabled = true,
    super.key,
  });

  /// Receives the dropped files in the order the platform reported them.
  final Future<void> Function(List<DropwellFile> files) onDrop;

  /// Called when a drag starts or stops hovering this region.
  final ValueChanged<bool>? onHoverChanged;

  /// Whether this region currently accepts drops.
  ///
  /// A disabled region withdraws its bounds, so the operating system shows a
  /// "no drop" cursor instead of accepting a payload the app would discard.
  final bool enabled;

  /// Subtree that acts as the drop target.
  final Widget child;

  @override
  State<DropwellRegion> createState() => _DropwellRegionState();
}

class _DropwellRegionState extends State<DropwellRegion>
    implements DropwellTarget {
  DropwellRegistry get _registry => DropwellRegistry.instance;

  @override
  void initState() {
    super.initState();
    _registry.register(this);
  }

  @override
  void dispose() {
    _registry.unregister(this);
    super.dispose();
  }

  @override
  Rect? get physicalBounds {
    if (!widget.enabled || !mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final origin = box.localToGlobal(Offset.zero);
    return DropwellGeometry.toPhysical(
      origin & box.size,
      View.of(context).devicePixelRatio,
    );
  }

  @override
  void onHoverChanged({required bool hovering}) =>
      widget.onHoverChanged?.call(hovering);

  @override
  Future<void> onDrop(List<DropwellFile> files) => widget.onDrop(files);

  @override
  Widget build(BuildContext context) => widget.child;
}
