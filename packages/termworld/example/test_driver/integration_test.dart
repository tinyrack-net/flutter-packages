import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  try {
    if (Platform.environment.containsKey('FLUTTER_WEB_TEST')) {
      await _grantClipboardPermission(driver);
    }

    final result = await driver.requestData(
      null,
      timeout: const Duration(minutes: 20),
    );
    final response = Response.fromJson(result);
    if (response.allTestsPassed) {
      stdout.writeln('All tests passed.');
      await writeResponseData(response.data);
      return;
    }

    stderr.writeln('Failure Details:\n${response.formattedFailureDetails}');
    exitCode = 1;
  } finally {
    await driver.close();
  }
}

Future<void> _grantClipboardPermission(FlutterDriver driver) async {
  final webDriver = driver.webDriver;
  final pageUri = Uri.parse(await webDriver.currentUrl);
  final endpoint = webDriver.uri.resolve(
    'session/${webDriver.id}/chromium/send_command_and_get_result',
  );
  final client = HttpClient();
  try {
    final body = utf8.encode(
      jsonEncode(<String, Object>{
        'cmd': 'Browser.grantPermissions',
        'params': <String, Object>{
          'origin': pageUri.origin,
          'permissions': <String>[
            'clipboardReadWrite',
            'clipboardSanitizedWrite',
          ],
        },
      }),
    );
    final request = await client.postUrl(endpoint);
    request.headers
      ..contentType = ContentType.json
      ..contentLength = body.length;
    request.add(body);
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'ChromeDriver rejected clipboard permission for ${pageUri.origin}: '
        '${response.statusCode} $responseBody',
      );
    }
  } finally {
    client.close(force: true);
  }
}
