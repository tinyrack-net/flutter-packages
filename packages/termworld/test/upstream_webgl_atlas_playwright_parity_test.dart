import 'package:flutter_test/flutter_test.dart';

import 'support/webgl_atlas_playwright_cases.dart';

void main() {
  test(
    'evicts before adding an oversized glyph page at the page cap',
    () => verifyWebglAtlasPlaywrightCase(
      'WebglAtlasOverflow.test.js atlas page overflow (#6038) '
      'evicts before adding an oversized glyph page at the '
      'page cap',
    ),
  );
  test(
    'evicts normal pages when the page cap cannot be reduced by merging',
    () => verifyWebglAtlasPlaywrightCase(
      'WebglAtlasOverflow.test.js atlas page overflow (#6038) '
      'evicts normal pages when the page cap cannot be '
      'reduced by merging',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'primary-buffer glyphs survive alternate-buffer redraws and atlas page churn',
    () => verifyWebglAtlasPlaywrightCase(
      'WebglAtlasStress.test.js WebGL atlas TUI stress '
      '(#6038) primary-buffer glyphs survive alternate-buffer '
      'redraws and atlas page churn',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'keeps a second terminal rendering correctly after shared atlas page merges',
    () => verifyWebglAtlasPlaywrightCase(
      'WebglSharedAtlasGarble.test.js shared-atlas garble '
      'across terminals (#6038) keeps a second terminal '
      'rendering correctly after shared atlas page merges',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'keeps a second terminal rendering correctly after terminal A clears the shared atlas',
    () => verifyWebglAtlasPlaywrightCase(
      'WebglSharedAtlasGarble.test.js shared-atlas garble '
      'across terminals (#6038) keeps a second terminal '
      'rendering correctly after terminal A clears the shared '
      'atlas',
    ),
  );
}
