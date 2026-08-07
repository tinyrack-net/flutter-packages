import 'dart:io';

import 'package:browsewell/browsewell.dart';
import 'package:browsewell_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates and displays a native browser', (tester) async {
    final profileDirectory = await Directory.systemTemp.createTemp(
      'browsewell-integration-',
    );
    final controller = await BrowsewellController.create(
      profile: BrowsewellProfile(directory: profileDirectory.path),
    );
    addTearDown(() async {
      await controller.dispose();
      await profileDirectory.delete(recursive: true);
    });

    await tester.pumpWidget(BrowsewellExample(controller: controller));
    await tester.pump();

    expect(find.byType(BrowsewellView), findsOneWidget);
    expect(controller.capabilities.multipleInstances, isTrue);
  });
}
