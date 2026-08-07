import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termworld_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('committed graphemes cross the text-input boundary once', (
    tester,
  ) async {
    await tester.pumpWidget(const TermworldExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('terminal')));
    tester.testTextInput.enterText('한글 👩🏽‍💻 ');
    await tester.pumpAndSettle();

    expect(find.text('한글 👩🏽‍💻 ', findRichText: true), findsOneWidget);
  });
}
