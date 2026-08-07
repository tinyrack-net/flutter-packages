import 'dart:async';

import 'package:browsewell/browsewell_platform_interface.dart';
import 'package:browsewell/src/browsewell_controller.dart';
import 'package:flutter/widgets.dart';

/// Flutter placeholder that positions one native desktop browser overlay.
final class BrowsewellView extends StatefulWidget {
  /// Creates a view for [controller].
  const BrowsewellView({required this.controller, super.key});

  /// Browser to present.
  final BrowsewellController controller;

  @override
  State<BrowsewellView> createState() => _BrowsewellViewState();
}

final class _BrowsewellViewState extends State<BrowsewellView> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportViewport());
    return BrowsewellPlatform.instance.buildView(widget.controller.id);
  }

  @override
  void deactivate() {
    unawaited(widget.controller.setViewport(Rect.zero, visible: false));
    super.deactivate();
  }

  void _reportViewport() {
    if (!mounted) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final origin = renderObject.localToGlobal(Offset.zero);
    unawaited(
      widget.controller.setViewport(origin & renderObject.size, visible: true),
    );
  }
}
