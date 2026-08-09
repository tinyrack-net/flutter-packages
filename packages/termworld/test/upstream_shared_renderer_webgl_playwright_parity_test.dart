import 'package:flutter_test/flutter_test.dart';

import 'support/shared_renderer_webgl_playwright_cases.dart';

void main() {
  testWidgets(
    'background 0-15 bright',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 0-15 bright',
    ),
  );
  testWidgets(
    'background 0-15 inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 0-15 inverse',
    ),
  );
  testWidgets(
    'background true color grey',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color grey',
    ),
  );
  testWidgets(
    'background 0-15 invisible',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 0-15 invisible',
    ),
  );
  testWidgets(
    'should adjust 0-15 colors on white background',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'minimumContrastRatio should adjust 0-15 colors on '
      'white background',
    ),
  );
  testWidgets(
    'background true color red',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color red',
    ),
  );
  testWidgets(
    'background true color grey inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color grey inverse',
    ),
  );
  testWidgets(
    '#4790: cursor should not be displayed before focusing',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'standalone tests (Shadow dom) regression tests #4790: '
      'cursor should not be displayed before focusing',
    ),
  );
  testWidgets(
    'foreground true color grey invisible',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color grey invisible',
    ),
  );
  testWidgets(
    'foreground 0-7 drawBoldTextInBrightColors',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 0-7 drawBoldTextInBrightColors',
    ),
  );
  testWidgets(
    'foreground 0-15 inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 0-15 inverse',
    ),
  );
  testWidgets(
    'foreground true color grey inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color grey inverse',
    ),
  );
  testWidgets(
    'background 16-255',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 16-255',
    ),
  );
  testWidgets(
    'background true color green inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color green inverse',
    ),
  );
  testWidgets(
    'foreground true color grey',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color grey',
    ),
  );
  testWidgets(
    'foreground true color blue',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color blue',
    ),
  );
  testWidgets(
    'foreground 16-255 dim',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 16-255 dim',
    ),
  );
  testWidgets(
    'foreground true color green',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color green',
    ),
  );
  testWidgets(
    'foreground true color green inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color green inverse',
    ),
  );
  testWidgets(
    '#4759: minimum contrast ratio should be respected on inverse text',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #4759: minimum contrast ratio should '
      'be respected on inverse text',
    ),
  );
  testWidgets(
    'foreground true color blue inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color blue inverse',
    ),
  );
  testWidgets(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    '#4759: minimum contrast ratio should be respected on selected inverse text',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #4759: minimum contrast ratio should '
      'be respected on selected inverse text',
    ),
  );
  testWidgets(
    'foreground true color red',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color red',
    ),
  );
  testWidgets(
    'background 16-255 dim',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 16-255 dim',
    ),
  );
  testWidgets(
    'foreground 16-255 inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 16-255 inverse',
    ),
  );
  testWidgets(
    'transparent background inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'allowTransparency transparent background inverse',
    ),
  );
  testWidgets(
    'foreground true color red inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground true color red inverse',
    ),
  );
  testWidgets(
    'background 0-15',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 0-15',
    ),
  );
  testWidgets(
    '#4799: cursor should be in the correct position',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #4799: cursor should be in the '
      'correct position',
    ),
  );
  testWidgets(
    'background true color blue inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color blue inverse',
    ),
  );
  testWidgets(
    'background 16-255 inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 16-255 inverse',
    ),
  );
  testWidgets(
    '#4790: cursor should not be displayed before focusing',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'standalone tests regression tests #4790: cursor should '
      'not be displayed before focusing',
    ),
  );
  testWidgets(
    'foreground 16-255 invisible',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 16-255 invisible',
    ),
  );
  testWidgets(
    'background true color red inverse',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color red inverse',
    ),
  );
  testWidgets(
    '#5241 cursor with alpha should blend color with background color',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #5241 cursor with alpha should blend '
      'color with background color',
    ),
  );
  testWidgets(
    'background 16-255 invisible',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background 16-255 invisible',
    ),
  );
  testWidgets(
    'should enforce half the contrast for dim cells',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'minimumContrastRatio should enforce half the contrast '
      'for dim cells',
    ),
  );
  testWidgets(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    '#4917 The selection should not be displayed if it is not within the scope of the viewport.',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #4917 The selection should not be '
      'displayed if it is not within the scope of the '
      'viewport.',
    ),
  );
  testWidgets(
    'foreground 0-15 bright',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 0-15 bright',
    ),
  );
  testWidgets(
    '#4773: block cursor should render when the cell is selected',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #4773: block cursor should render '
      'when the cell is selected',
    ),
  );
  testWidgets(
    'background true color grey invisible',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color grey invisible',
    ),
  );
  testWidgets(
    'foreground 0-15',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'colors foreground 0-15',
    ),
  );
  testWidgets(
    '#5241 cursorAccent with alpha should blend color with background color',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #5241 cursorAccent with alpha should '
      'blend color with background color',
    ),
  );
  testWidgets(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    '#4758: multiple invisible text characters without SGR change should not be rendered',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'regression tests #4758: multiple invisible text '
      'characters without SGR change should not be rendered',
    ),
  );
  testWidgets(
    'background true color green',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color green',
    ),
  );
  testWidgets(
    'foreground 0-15 invisible',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 0-15 invisible',
    ),
  );
  testWidgets(
    'foreground 16-255',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'foreground 16-255',
    ),
  );
  testWidgets(
    'background true color blue',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'background true color blue',
    ),
  );
  testWidgets(
    'should adjust 0-15 colors on black background',
    (tester) => verifyWebglSharedRendererPlaywrightCase(
      tester,
      'minimumContrastRatio should adjust 0-15 colors on '
      'black background',
    ),
  );
}
