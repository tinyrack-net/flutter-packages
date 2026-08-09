import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/addon_image.dart';

void main() {
  test('xterm IIPMetrics 00', () {
    final fixtureRoot = Directory.current.path.endsWith('termworld')
        ? 'test/fixtures/xterm_image'
        : 'packages/termworld/test/fixtures/xterm_image';
    final document =
        jsonDecode(
              File('$fixtureRoot/image_metrics_cases.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    if (document['revision'] != '904ae935269eef5ec6a1415b64463c3d02eff1eb') {
      throw StateError('IIP metrics fixture revision changed');
    }
    final cases = (document['cases']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(cases, hasLength(20));
    for (final entry in cases) {
      final data = Uint8List.fromList(
        File('$fixtureRoot/testimages/${entry['file']}').readAsBytesSync(),
      );
      final metrics = iipImageType(data);
      expect(metrics.mime, entry['mime'], reason: entry['file']! as String);
      expect(metrics.width, entry['width'], reason: entry['file']! as String);
      expect(metrics.height, entry['height'], reason: entry['file']! as String);
    }
  });
}
