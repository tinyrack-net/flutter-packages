import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dropwell/src/dropwell_file.dart';
import 'package:web/web.dart' as web;

/// Reads files out of a browser [web.DataTransfer].
///
/// A drop and a paste both arrive as a `DataTransfer`, so one reader serves
/// both and neither can quietly support a shape the other does not. A browser
/// never hands out a path, so every file comes back as bytes.
Future<List<DropwellFile>> readDataTransfer(web.DataTransfer? transfer) async {
  if (transfer == null) return const <DropwellFile>[];
  final files = transfer.files;
  final result = <DropwellFile>[];
  for (var index = 0; index < files.length; index++) {
    final file = files.item(index);
    if (file == null) continue;
    result.add(
      DropwellFile.bytes(
        fileName: file.name,
        bytes: await _readBytes(file),
        // A browser reports an empty type rather than omitting it, which is
        // "I do not know" and must not become a media type of "".
        mimeType: file.type.isEmpty ? null : file.type,
      ),
    );
  }
  return List<DropwellFile>.unmodifiable(result);
}

Future<Uint8List> _readBytes(web.File file) async {
  final buffer = await file.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}
