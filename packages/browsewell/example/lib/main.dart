import 'dart:io';

import 'package:browsewell/browsewell.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profileDirectory = await Directory.systemTemp.createTemp(
    'browsewell-example-',
  );
  final controller = await BrowsewellController.create(
    profile: BrowsewellProfile(directory: profileDirectory.path),
  );
  runApp(BrowsewellExample(controller: controller));
}

/// Minimal application used by the desktop conformance suite.
final class BrowsewellExample extends StatelessWidget {
  /// Creates the example.
  const BrowsewellExample({required this.controller, super.key});

  /// Browser displayed by the application.
  final BrowsewellController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: BrowsewellView(controller: controller)),
  );
}
