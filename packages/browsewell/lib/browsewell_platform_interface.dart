import 'package:browsewell/src/browsewell_models.dart';
import 'package:browsewell/src/webview_all_browsewell_platform.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Platform contract implemented by each desktop browser backend.
abstract class BrowsewellPlatform extends PlatformInterface {
  /// Creates a platform implementation.
  BrowsewellPlatform() : super(token: _token);

  static final Object _token = Object();
  static BrowsewellPlatform _instance = WebviewAllBrowsewellPlatform();

  /// Active platform implementation.
  static BrowsewellPlatform get instance => _instance;

  /// Replaces the active implementation.
  static set instance(BrowsewellPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Creates one native browser.
  Future<BrowsewellCreateResult> create(BrowsewellCreateRequest request) =>
      throw UnimplementedError('create() has not been implemented.');

  /// Executes one browser command.
  Future<Object?> execute(String id, BrowsewellCommand command) =>
      throw UnimplementedError('execute() has not been implemented.');

  /// Streams state changes from one browser.
  Stream<BrowsewellEvent> events(String id) =>
      throw UnimplementedError('events() has not been implemented.');

  /// Positions the native view above its Flutter placeholder.
  Future<void> setViewport(
    String id, {
    required Rect rect,
    required bool visible,
  }) => throw UnimplementedError('setViewport() has not been implemented.');

  /// Disposes one native browser.
  Future<void> disposeBrowser(String id) =>
      throw UnimplementedError('disposeBrowser() has not been implemented.');

  /// Builds the renderer owned by [id].
  Widget buildView(String id) =>
      throw UnimplementedError('buildView() has not been implemented.');
}
