import 'package:flutter_test/flutter_test.dart';

import 'support/shared_renderer_webgl_playwright_cases.dart';

void main() {
  test(
    'background 0-15 bright',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 0-15 bright',
    ),
  );
  test(
    'background 0-15 inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 0-15 inverse',
    ),
  );
  test(
    'background true color grey',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color grey',
    ),
  );
  test(
    'background 0-15 invisible',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 0-15 invisible',
    ),
  );
  test(
    'should adjust 0-15 colors on white background',
    () => verifyWebglSharedRendererPlaywrightCase(
      'minimumContrastRatio should adjust 0-15 colors on '
      'white background',
    ),
  );
  test(
    'background true color red',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color red',
    ),
  );
  test(
    'background true color grey inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color grey inverse',
    ),
  );
  testWidgets(
    '#4790: cursor should not be displayed before focusing',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      'standalone tests (Shadow dom) regression tests #4790: '
      'cursor should not be displayed before focusing',
      tester: tester,
    ),
  );
  test(
    'foreground true color grey invisible',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color grey invisible',
    ),
  );
  test(
    'foreground 0-7 drawBoldTextInBrightColors',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 0-7 drawBoldTextInBrightColors',
    ),
  );
  test(
    'foreground 0-15 inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 0-15 inverse',
    ),
  );
  test(
    'foreground true color grey inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color grey inverse',
    ),
  );
  test(
    'background 16-255',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 16-255',
    ),
  );
  test(
    'background true color green inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color green inverse',
    ),
  );
  test(
    'foreground true color grey',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color grey',
    ),
  );
  test(
    'foreground true color blue',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color blue',
    ),
  );
  test(
    'foreground 16-255 dim',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 16-255 dim',
    ),
  );
  test(
    'foreground true color green',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color green',
    ),
  );
  test(
    'foreground true color green inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color green inverse',
    ),
  );
  test(
    '#4759: minimum contrast ratio should be respected on inverse text',
    () => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #4759: minimum contrast ratio should '
      'be respected on inverse text',
    ),
  );
  test(
    'foreground true color blue inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color blue inverse',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    '#4759: minimum contrast ratio should be respected on selected inverse text',
    () => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #4759: minimum contrast ratio should '
      'be respected on selected inverse text',
    ),
  );
  test(
    'foreground true color red',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color red',
    ),
  );
  test(
    'background 16-255 dim',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 16-255 dim',
    ),
  );
  test(
    'foreground 16-255 inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 16-255 inverse',
    ),
  );
  test(
    'transparent background inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'allowTransparency transparent background inverse',
    ),
  );
  test(
    'foreground true color red inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground true color red inverse',
    ),
  );
  test(
    'background 0-15',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 0-15',
    ),
  );
  testWidgets(
    '#4799: cursor should be in the correct position',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #4799: cursor should be in the '
      'correct position',
      tester: tester,
    ),
  );
  test(
    'background true color blue inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color blue inverse',
    ),
  );
  test(
    'background 16-255 inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 16-255 inverse',
    ),
  );
  testWidgets(
    '#4790: cursor should not be displayed before focusing',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      'standalone tests regression tests #4790: cursor should '
      'not be displayed before focusing',
      tester: tester,
    ),
  );
  test(
    'foreground 16-255 invisible',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 16-255 invisible',
    ),
  );
  test(
    'background true color red inverse',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color red inverse',
    ),
  );
  testWidgets(
    '#5241 cursor with alpha should blend color with background color',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #5241 cursor with alpha should blend '
      'color with background color',
      tester: tester,
    ),
  );
  test(
    'background 16-255 invisible',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background 16-255 invisible',
    ),
  );
  test(
    'should enforce half the contrast for dim cells',
    () => verifyWebglSharedRendererPlaywrightCase(
      'minimumContrastRatio should enforce half the contrast '
      'for dim cells',
    ),
  );
  testWidgets(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    '#4917 The selection should not be displayed if it is not within the scope of the viewport.',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #4917 The selection should not be '
      'displayed if it is not within the scope of the '
      'viewport.',
      tester: tester,
    ),
  );
  test(
    'foreground 0-15 bright',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 0-15 bright',
    ),
  );
  testWidgets(
    '#4773: block cursor should render when the cell is selected',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #4773: block cursor should render '
      'when the cell is selected',
      tester: tester,
    ),
  );
  test(
    'background true color grey invisible',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color grey invisible',
    ),
  );
  test(
    'foreground 0-15',
    () => verifyWebglSharedRendererPlaywrightCase(
      'colors foreground 0-15',
    ),
  );
  testWidgets(
    '#5241 cursorAccent with alpha should blend color with background color',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #5241 cursorAccent with alpha should '
      'blend color with background color',
      tester: tester,
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    '#4758: multiple invisible text characters without SGR change should not be rendered',
    () => verifyWebglSharedRendererPlaywrightCase(
      'regression tests #4758: multiple invisible text '
      'characters without SGR change should not be rendered',
    ),
  );
  test(
    'background true color green',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color green',
    ),
  );
  test(
    'foreground 0-15 invisible',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 0-15 invisible',
    ),
  );
  test(
    'foreground 16-255',
    () => verifyWebglSharedRendererPlaywrightCase(
      'foreground 16-255',
    ),
  );
  test(
    'background true color blue',
    () => verifyWebglSharedRendererPlaywrightCase(
      'background true color blue',
    ),
  );
  test(
    'should adjust 0-15 colors on black background',
    () => verifyWebglSharedRendererPlaywrightCase(
      'minimumContrastRatio should adjust 0-15 colors on '
      'black background',
    ),
  );
}
