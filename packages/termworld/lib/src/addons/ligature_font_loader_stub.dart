import 'package:termworld/src/addons/ligature_font.dart';

/// Local Font Access is browser-only; other platforms use fallback ligatures.
Future<TerminalLigatureFont?> loadTerminalLigatureFont(
  String fontFamily,
  int cacheSize,
) async => null;
