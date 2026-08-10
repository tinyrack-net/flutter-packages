import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:termworld/src/addons/webgl_web.dart';
import 'package:vtworld/vtworld.dart';

final Expando<bool> _registered = Expando<bool>();

/// Returns the canvas owned by the active WebGL addon for [terminal].
Widget? terminalWebglSurface(Terminal terminal) {
  final addon = WebglAddon.activeFor(terminal);
  final canvas = addon?.rendererCanvas;
  if (addon == null || canvas == null) return null;
  final viewType = addon.rendererViewType;
  if (_registered[addon] != true) {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => canvas,
    );
    _registered[addon] = true;
  }
  canvas.style
    ..width = '100%'
    ..height = '100%'
    ..display = 'block';
  addon.renderFrame();
  return HtmlElementView(viewType: viewType);
}
