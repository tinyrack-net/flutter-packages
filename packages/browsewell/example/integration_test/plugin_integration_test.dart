import 'package:browsewell/browsewell.dart';
import 'package:browsewell_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates and displays a native browser', (tester) async {
    final controller = await BrowsewellController.create(
      profile: const BrowsewellProfile(id: 'net.tinyrack.browsewell.example'),
    );
    addTearDown(() async {
      await controller.dispose();
    });

    await tester.pumpWidget(BrowsewellExample(controller: controller));
    await tester.pump();

    expect(find.byType(BrowsewellView), findsOneWidget);
    expect(controller.capabilities.multipleInstances, isTrue);
  });
}
