import 'package:flutter_test/flutter_test.dart';

import 'support/kitty_graphics_playwright_cases.dart';

void main() {
  test(
    'renders pixels correctly when placing raw RGBA image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) renders pixels correctly when '
      'placing raw RGBA image',
    ),
  );
  test(
    'delete by id only aborts targeted upload, not others',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands delete by id only aborts targeted '
      'upload, not others',
    ),
  );
  test(
    'a=T sends EINVAL when raw pixel render fails (missing dimensions)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=T sends '
      'EINVAL when raw pixel render fails (missing '
      'dimensions)',
    ),
  );
  test(
    'stores image with correct original dimensions (5x1)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Storage and dimensions '
      'stores image with correct original dimensions (5x1)',
    ),
  );
  test(
    'responds with OK for valid PNG query',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) responds with OK for valid PNG '
      'query',
    ),
  );
  test(
    'query returns OK for valid RGBA data with correct dimensions',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Validation query '
      'returns OK for valid RGBA data with correct '
      'dimensions',
    ),
  );
  test(
    'renders 3x1 strip (red, green, blue opaque)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Pixel verification '
      'renders 3x1 strip (red, green, blue opaque)',
    ),
  );
  test(
    'd=i selector also removes displayed image from storage',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=i selector also removes displayed '
      'image from storage',
    ),
  );
  test(
    'stores image with correct original dimensions (4x2)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Storage and dimensions '
      'stores image with correct original dimensions (4x2)',
    ),
  );
  test(
    'a=T sends OK on successful render with id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=T sends '
      'OK on successful render with id',
    ),
  );
  test(
    'image data remains available after placement for future placements',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) image data remains available '
      'after placement for future placements',
    ),
  );
  test(
    'a=t OK suppressed by q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=t OK '
      'suppressed by q=2',
    ),
  );
  test(
    'query does not store the 200x100 image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Query support '
      'query does not store the 200x100 image',
    ),
  );
  test(
    'a=T OK suppressed by q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=T OK '
      'suppressed by q=2',
    ),
  );
  test(
    'onImageAdded fires for each kitty image',
    () => verifyKittyGraphicsPlaywrightCase(
      'onImageAdded callback onImageAdded fires for each '
      'kitty image',
    ),
  );
  test(
    'transmit+display rejects t=t with id (EINVAL response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit+display '
      'rejects t=t with id (EINVAL response)',
    ),
  );
  test(
    'responds with EINVAL for i+I conflict even without payload',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) responds with EINVAL for i+I '
      'conflict even without payload',
    ),
  );
  test(
    'only r specified computes c from aspect ratio',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) only r specified computes c '
      'from aspect ratio',
    ),
  );
  test(
    'cursor advances past placed image (default C=0)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) cursor advances past placed '
      'image (default C=0)',
    ),
  );
  test(
    'delete all aborts in-flight chunked upload',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands delete all aborts in-flight chunked '
      'upload',
    ),
  );
  test(
    'cursor should move down by rows when r specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor should move down by rows '
      'when r specified',
    ),
  );
  test(
    'cursor advances past 1x1 image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor advances past 1x1 image',
    ),
  );
  test(
    'transmit+display rejects t=s with id (EINVAL response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit+display '
      'rejects t=s with id (EINVAL response)',
    ),
  );
  test(
    'query rejects t=s (shared memory)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection query rejects t=s '
      '(shared memory)',
    ),
  );
  test(
    'renders 1x1 opaque red pixel',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Pixel verification '
      'renders 1x1 opaque red pixel',
    ),
  );
  test(
    'renders 5x1 row with block+remainder pixel layout',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Pixel verification '
      'renders 5x1 row with block+remainder pixel layout',
    ),
  );
  test(
    'chunked a=T works when subsequent chunks omit i= (spec pattern)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission chunked a=T works when '
      'subsequent chunks omit i= (spec pattern)',
    ),
  );
  test(
    'only c specified computes r from aspect ratio',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) only c specified computes r '
      'from aspect ratio',
    ),
  );
  test(
    'does not render without either dimension',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Validation does not '
      'render without either dimension',
    ),
  );
  test(
    'query returns EINVAL without dimensions',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Validation query '
      'returns EINVAL without dimensions',
    ),
  );
  test(
    'defaults to transmit action when action is omitted',
    () => verifyKittyGraphicsPlaywrightCase(
      'Basic transmission and storage defaults to transmit '
      'action when action is omitted',
    ),
  );
  test(
    'responds OK on successful placement',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) responds OK on successful '
      'placement',
    ),
  );
  test(
    'renders 2x2 grid with correct pixel layout',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Pixel verification '
      'renders 2x2 grid with correct pixel layout',
    ),
  );
  test(
    'applies source crop via x/y/w/h before display',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification applies source crop via x/y/w/h before '
      'display',
    ),
  );
  test(
    'z=1 (positive) stores image on top layer',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement z=1 (positive) stores image '
      'on top layer',
    ),
  );
  test(
    'stores image with correct original dimensions (3x1)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Storage and dimensions '
      'stores image with correct original dimensions (3x1)',
    ),
  );
  test(
    'does not render with insufficient byte count',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Validation does not '
      'render with insufficient byte count',
    ),
  );
  test(
    'a=T OK suppressed by q=1',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=T OK '
      'suppressed by q=1',
    ),
  );
  test(
    'stores image with correct original dimensions (2x2)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Storage and dimensions '
      'stores image with correct original dimensions (2x2)',
    ),
  );
  test(
    'unsupported delete selector is ignored',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands unsupported delete selector is '
      'ignored',
    ),
  );
  test(
    'd=a selector clears all pixels from canvas',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=a selector clears all pixels from '
      'canvas',
    ),
  );
  test(
    'does not render without height (v=)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Validation does not '
      'render without height (v=)',
    ),
  );
  test(
    'stores 1x1 black PNG with a=T (transmit and display)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Basic transmission and storage stores 1x1 black PNG '
      'with a=T (transmit and display)',
    ),
  );
  test(
    'scrollback eviction cleans Kitty handler maps',
    () => verifyKittyGraphicsPlaywrightCase(
      'Eviction and memory leak prevention scrollback '
      'eviction cleans Kitty handler maps',
    ),
  );
  test(
    'uses specified image ID',
    () => verifyKittyGraphicsPlaywrightCase(
      'Basic transmission and storage uses specified image '
      'ID',
    ),
  );
  test(
    'transmit+display rejects t=f with id (EINVAL response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit+display '
      'rejects t=f with id (EINVAL response)',
    ),
  );
  test(
    'renders 1x1 black pixel with alpha set to 255',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Pixel verification '
      'renders 1x1 black pixel with alpha set to 255',
    ),
  );
  test(
    'preserves full transparency (alpha=0)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Pixel verification '
      'preserves full transparency (alpha=0)',
    ),
  );
  test(
    'a=t sends OK on successful transmit with id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=t sends '
      'OK on successful transmit with id',
    ),
  );
  test(
    'cursor advances with text before image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor advances with text before '
      'image',
    ),
  );
  test(
    'does not render without height (v=)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Validation does not '
      'render without height (v=)',
    ),
  );
  test(
    'responds with error for RGB data without dimensions',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) responds with error for RGB data '
      'without dimensions',
    ),
  );
  test(
    'a=T sends no response on decode error without id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=T sends '
      'no response on decode error without id',
    ),
  );
  test(
    'renders pixels correctly when placing raw RGB image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) renders pixels correctly when '
      'placing raw RGB image',
    ),
  );
  test(
    'd=a selector deletes all images',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=a selector deletes all images',
    ),
  );
  test(
    'renders correct color at bottom-right corner',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification renders correct color at bottom-right '
      'corner',
    ),
  );
  test(
    're-transmit with same i= cleans up old storage entry',
    () => verifyKittyGraphicsPlaywrightCase(
      'Eviction and memory leak prevention re-transmit with '
      'same i= cleans up old storage entry',
    ),
  );
  test(
    'chunked transfer responds OK on final chunk when i= on first only',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission chunked transfer responds OK on '
      'final chunk when i= on first only',
    ),
  );
  test(
    'ENOENT error suppressed by q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) ENOENT error suppressed by '
      'q=2',
    ),
  );
  test(
    'query returns EINVAL for insufficient pixel data',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Validation query returns '
      'EINVAL for insufficient pixel data',
    ),
  );
  test(
    'renders 3x1 RGB PNG (red, green, blue pixels)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Pixel verification renders 3x1 RGB PNG (red, green, '
      'blue pixels)',
    ),
  );
  test(
    'query does NOT store the image (unlike transmit)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) query does NOT store the image '
      '(unlike transmit)',
    ),
  );
  test(
    'does not render with insufficient byte count',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Validation does not '
      'render with insufficient byte count',
    ),
  );
  test(
    'renders 1x1 red pixel with alpha set to 255',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Pixel verification '
      'renders 1x1 red pixel with alpha set to 255',
    ),
  );
  test(
    'responds with error for invalid base64',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) responds with error for invalid '
      'base64',
    ),
  );
  test(
    'a=t sends EINVAL on decode error when id is specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=t sends '
      'EINVAL on decode error when id is specified',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'z=-1 (negative) stores image on bottom layer when allowTransparency is enabled',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement z=-1 (negative) stores image '
      'on bottom layer when allowTransparency is enabled',
    ),
  );
  test(
    'verifies chunked data assembles correctly',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Chunked '
      'transmission verifies chunked data assembles '
      'correctly',
    ),
  );
  test(
    'suppresses OK response when q=1',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) suppresses OK response when q=1',
    ),
  );
  test(
    'memory limit eviction cleans Kitty handler maps',
    () => verifyKittyGraphicsPlaywrightCase(
      'Eviction and memory leak prevention memory limit '
      'eviction cleans Kitty handler maps',
    ),
  );
  test(
    'handles 3-chunk transmission',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Chunked '
      'transmission handles 3-chunk transmission',
    ),
  );
  test(
    'a=T EINVAL suppressed by q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=T EINVAL '
      'suppressed by q=2',
    ),
  );
  test(
    'bottom layer canvas is before text canvas in DOM order',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement bottom layer canvas is '
      'before text canvas in DOM order',
    ),
  );
  test(
    'suppresses error response when q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) suppresses error response when '
      'q=2',
    ),
  );
  test(
    'ignores command when action is empty string',
    () => verifyKittyGraphicsPlaywrightCase(
      'Basic transmission and storage ignores command when '
      'action is empty string',
    ),
  );
  test(
    'multiple placements of same image create separate displays',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) multiple placements of same '
      'image create separate displays',
    ),
  );
  test(
    'transmit+display rejects t=f without id (no response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit+display '
      'rejects t=f without id (no response)',
    ),
  );
  test(
    'does not render without either dimension',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Validation does not '
      'render without either dimension',
    ),
  );
  test(
    'cursor uses explicit c and r over image dimensions',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Cursor '
      'positioning cursor uses explicit c and r over image '
      'dimensions',
    ),
  );
  test(
    'cursor does not move with C=1',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Cursor '
      'positioning cursor does not move with C=1',
    ),
  );
  test(
    'stores 200x100 PNG with a=T',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Basic '
      'transmission and storage stores 200x100 PNG with a=T',
    ),
  );
  test(
    'renders 1x1 black PNG at cursor position',
    () => verifyKittyGraphicsPlaywrightCase(
      'Pixel verification renders 1x1 black PNG at cursor '
      'position',
    ),
  );
  test(
    'chunked a=T without i= on any chunk works (no response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission chunked a=T without i= on any '
      'chunk works (no response)',
    ),
  );
  test(
    'query returns EINVAL for insufficient pixel data',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Validation query '
      'returns EINVAL for insufficient pixel data',
    ),
  );
  test(
    'renders top row colors at rectangle centers',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification renders top row colors at rectangle '
      'centers',
    ),
  );
  test(
    'supports z-index (negative = bottom layer)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) supports z-index (negative = '
      'bottom layer)',
    ),
  );
  test(
    'suppresses OK response when q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) suppresses OK response when q=2',
    ),
  );
  test(
    'chunks sent after delete are not assembled with previous data',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands chunks sent after delete are not '
      'assembled with previous data',
    ),
  );
  test(
    'query returns OK for valid RGB data with correct dimensions',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Validation query returns '
      'OK for valid RGB data with correct dimensions',
    ),
  );
  test(
    'cursor advances past multi-cell image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Cursor '
      'positioning cursor advances past multi-cell image',
    ),
  );
  test(
    'stores 3x1 RGB PNG with a=T',
    () => verifyKittyGraphicsPlaywrightCase(
      'Basic transmission and storage stores 3x1 RGB PNG '
      'with a=T',
    ),
  );
  test(
    'renders 1x1 opaque white pixel',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Pixel verification '
      'renders 1x1 opaque white pixel',
    ),
  );
  test(
    'query without t key defaults to direct (OK)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection query without t key '
      'defaults to direct (OK)',
    ),
  );
  test(
    'renders a strip of top-row pixels via getPixels',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification renders a strip of top-row pixels via '
      'getPixels',
    ),
  );
  test(
    'renders correct colors at rectangle boundaries',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification renders correct colors at rectangle '
      'boundaries',
    ),
  );
  test(
    'does not render without width (s=)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Validation does not '
      'render without width (s=)',
    ),
  );
  test(
    'top layer canvas has correct CSS class',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement top layer canvas has correct '
      'CSS class',
    ),
  );
  test(
    'z=0 stores image on top layer',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement z=0 stores image on top '
      'layer',
    ),
  );
  test(
    'cursor should calculate cols/rows from image size when not specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor should calculate cols/rows '
      'from image size when not specified',
    ),
  );
  test(
    'scales cropped source region to c/r placement rectangle',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification scales cropped source region to c/r '
      'placement rectangle',
    ),
  );
  test(
    'stores image with correct original dimensions (2x2)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Storage and dimensions '
      'stores image with correct original dimensions (2x2)',
    ),
  );
  test(
    'displays a previously transmitted image at cursor',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) displays a previously '
      'transmitted image at cursor',
    ),
  );
  test(
    'responds with OK for valid 200x100 PNG query',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Query support '
      'responds with OK for valid 200x100 PNG query',
    ),
  );
  test(
    'renders bottom row colors at rectangle centers',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification renders bottom row colors at rectangle '
      'centers',
    ),
  );
  test(
    'negative x/y values are clamped to 0',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification negative x/y values are clamped to 0',
    ),
  );
  test(
    'ENOENT still reported when q=1 (only suppresses OK)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) ENOENT still reported when '
      'q=1 (only suppresses OK)',
    ),
  );
  test(
    'query returns EINVAL without dimensions',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Validation query returns '
      'EINVAL without dimensions',
    ),
  );
  test(
    'd=A selector deletes all images (uppercase)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=A selector deletes all images '
      '(uppercase)',
    ),
  );
  test(
    'transmit rejects t=t with id (EINVAL response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit rejects t=t '
      'with id (EINVAL response)',
    ),
  );
  test(
    'query accepts t=d (direct transmission)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection query accepts t=d '
      '(direct transmission)',
    ),
  );
  test(
    'cursor should NOT move when C=1 is specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor should NOT move when C=1 '
      'is specified',
    ),
  );
  test(
    'verifies chunked data is assembled correctly',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission verifies chunked data is '
      'assembled correctly',
    ),
  );
  test(
    'delete command (a=d) removes all images when no id specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands delete command (a=d) removes all '
      'images when no id specified',
    ),
  );
  test(
    'chunked data without i= on subsequent chunks is assembled correctly',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission chunked data without i= on '
      'subsequent chunks is assembled correctly',
    ),
  );
  test(
    'x exceeding image width produces no display',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification x exceeding image width produces no '
      'display',
    ),
  );
  test(
    'responds ENOENT for non-existent image id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) responds ENOENT for '
      'non-existent image id',
    ),
  );
  test(
    'handles 2-chunk transmission',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Chunked '
      'transmission handles 2-chunk transmission',
    ),
  );
  test(
    'renders pixels correctly when placing a PNG image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) renders pixels correctly when '
      'placing a PNG image',
    ),
  );
  test(
    'transmit only (a=t) does not display but stores in handler',
    () => verifyKittyGraphicsPlaywrightCase(
      'Basic transmission and storage transmit only (a=t) '
      'does not display but stores in handler',
    ),
  );
  test(
    'cursor position with multiple images on same line',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor position with multiple '
      'images on same line',
    ),
  );
  test(
    'a=t EINVAL suppressed by q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=t EINVAL '
      'suppressed by q=2',
    ),
  );
  test(
    'renders 4x2 grid with multi-block pixel layout',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Pixel verification '
      'renders 4x2 grid with multi-block pixel layout',
    ),
  );
  test(
    'supports source crop via x/y',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) supports source crop via x/y',
    ),
  );
  test(
    'stores image with correct original dimensions (5x1)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Storage and dimensions '
      'stores image with correct original dimensions (5x1)',
    ),
  );
  test(
    'a=T sends EINVAL on decode error when id is specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=T sends '
      'EINVAL on decode error when id is specified',
    ),
  );
  test(
    'without id sends no response',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) without id sends no response',
    ),
  );
  test(
    'a=t sends no response on decode error without id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=t sends '
      'no response on decode error without id',
    ),
  );
  test(
    'handles chunked transmission (m=1)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission handles chunked transmission '
      '(m=1)',
    ),
  );
  test(
    'stores image with correct original dimensions (3x1)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Storage and dimensions '
      'stores image with correct original dimensions (3x1)',
    ),
  );
  test(
    'renders 3x1 strip (red, green, blue)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Pixel verification '
      'renders 3x1 strip (red, green, blue)',
    ),
  );
  test(
    'applies sub-cell offset via X/Y within first cell',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification applies sub-cell offset via X/Y within '
      'first cell',
    ),
  );
  test(
    'renders red rectangle at top-left origin (0,0)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification renders red rectangle at top-left '
      'origin (0,0)',
    ),
  );
  test(
    'd=i selector deletes specific image by id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=i selector deletes specific image '
      'by id',
    ),
  );
  test(
    'does not render without width (s=)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Validation does not '
      'render without width (s=)',
    ),
  );
  test(
    'stores with specified image ID',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Basic '
      'transmission and storage stores with specified image '
      'ID',
    ),
  );
  test(
    'responds with EINVAL when both i and I keys are specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) responds with EINVAL when both i '
      'and I keys are specified',
    ),
  );
  test(
    'query rejects t=f (file transmission)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection query rejects t=f '
      '(file transmission)',
    ),
  );
  test(
    'cursor advances on newline after image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor advances on newline after '
      'image',
    ),
  );
  test(
    'd=a selector also removes displayed images from storage',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=a selector also removes displayed '
      'images from storage',
    ),
  );
  test(
    'delete command (a=d,d=i) removes specific image by id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands delete command (a=d,d=i) removes '
      'specific image by id',
    ),
  );
  test(
    'renders 2x2 grid with correct pixel layout',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGB pixel format (f=24) Pixel verification '
      'renders 2x2 grid with correct pixel layout',
    ),
  );
  test(
    'three-chunk transfer with only m= on middle and last chunks',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission three-chunk transfer with only '
      'm= on middle and last chunks',
    ),
  );
  test(
    'supports sub-cell offset via X/Y',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) supports sub-cell offset via '
      'X/Y',
    ),
  );
  test(
    'delete by id aborts in-flight chunked upload',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands delete by id aborts in-flight '
      'chunked upload',
    ),
  );
  test(
    'd=I selector deletes specific image by id (uppercase)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=I selector deletes specific image '
      'by id (uppercase)',
    ),
  );
  test(
    'transmit rejects t=f with id (EINVAL response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit rejects t=f '
      'with id (EINVAL response)',
    ),
  );
  test(
    'z=-1 uses bottom layer even when allowTransparency is disabled',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement z=-1 uses bottom layer even '
      'when allowTransparency is disabled',
    ),
  );
  test(
    'cursor should move by cols AND rows when both specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor should move by cols AND '
      'rows when both specified',
    ),
  );
  test(
    'h=0 is treated as unset (displays full height)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification h=0 is treated as unset (displays full '
      'height)',
    ),
  );
  test(
    'bottom layer canvas has correct CSS class',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement bottom layer canvas has '
      'correct CSS class',
    ),
  );
  test(
    'transmit rejects t=f without id (no response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit rejects t=f '
      'without id (no response)',
    ),
  );
  test(
    // Exact pinned identity remains one literal.
    // ignore: lines_longer_than_80_chars
    'z=-100 (large negative) stores image on bottom layer when allowTransparency is enabled',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement z=-100 (large negative) '
      'stores image on bottom layer when allowTransparency '
      'is enabled',
    ),
  );
  test(
    'sub-cell offset with explicit c/r advances cursor correctly',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification sub-cell offset with explicit c/r '
      'advances cursor correctly',
    ),
  );
  test(
    'transmit rejects t=s with id (EINVAL response)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection transmit rejects t=s '
      'with id (EINVAL response)',
    ),
  );
  test(
    'OK response suppressed by q=2',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) OK response suppressed by q=2',
    ),
  );
  test(
    'delete removes 200x100 image by id',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Delete '
      'commands delete removes 200x100 image by id',
    ),
  );
  test(
    'enforces size limit across chunked transmissions',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission enforces size limit across '
      'chunked transmissions',
    ),
  );
  test(
    'cursor should move right by cols when c specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor should move right by cols '
      'when c specified',
    ),
  );
  test(
    'a=t OK suppressed by q=1',
    () => verifyKittyGraphicsPlaywrightCase(
      'Error responses for transmit and display a=t OK '
      'suppressed by q=1',
    ),
  );
  test(
    'd=i selector clears pixels from canvas',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=i selector clears pixels from '
      'canvas',
    ),
  );
  test(
    'w=0 is treated as unset (displays full width)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification w=0 is treated as unset (displays full '
      'width)',
    ),
  );
  test(
    'd=i without id does nothing',
    () => verifyKittyGraphicsPlaywrightCase(
      'Delete commands d=i without id does nothing',
    ),
  );
  test(
    'responds with OK for capability query without payload',
    () => verifyKittyGraphicsPlaywrightCase(
      'Query support (a=q) responds with OK for capability '
      'query without payload',
    ),
  );
  test(
    'places at specified column/row size (c/r)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) places at specified '
      'column/row size (c/r)',
    ),
  );
  test(
    'response includes placement id when p is specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) response includes placement '
      'id when p is specified',
    ),
  );
  test(
    'default placement (no z key) stores image on top layer',
    () => verifyKittyGraphicsPlaywrightCase(
      'Z-index layer placement default placement (no z key) '
      'stores image on top layer',
    ),
  );
  test(
    'transmit only (a=t) stores 200x100 image without display',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Basic '
      'transmission and storage transmit only (a=t) stores '
      '200x100 image without display',
    ),
  );
  test(
    'OK response suppressed by q=1',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) OK response suppressed by q=1',
    ),
  );
  test(
    'query rejects t=t (temp file)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Transmission medium rejection query rejects t=t '
      '(temp file)',
    ),
  );
  test(
    'renders 5x1 row with zero-copy pixel layout',
    () => verifyKittyGraphicsPlaywrightCase(
      'Raw RGBA pixel format (f=32) Pixel verification '
      'renders 5x1 row with zero-copy pixel layout',
    ),
  );
  test(
    'chunked a=t works when subsequent chunks omit i= (spec pattern)',
    () => verifyKittyGraphicsPlaywrightCase(
      'Chunked transmission chunked a=t works when '
      'subsequent chunks omit i= (spec pattern)',
    ),
  );
  test(
    'cursor advances with text after image',
    () => verifyKittyGraphicsPlaywrightCase(
      'Cursor positioning cursor advances with text after '
      'image',
    ),
  );
  test(
    're-transmit with a=t then a=T cleans old storage before display',
    () => verifyKittyGraphicsPlaywrightCase(
      'Eviction and memory leak prevention re-transmit with '
      'a=t then a=T cleans old storage before display',
    ),
  );
  test(
    'cursor does not move when C=1',
    () => verifyKittyGraphicsPlaywrightCase(
      'Placement action (a=p) cursor does not move when C=1',
    ),
  );
  test(
    'assigns auto-incrementing IDs when not specified',
    () => verifyKittyGraphicsPlaywrightCase(
      'Basic transmission and storage assigns '
      'auto-incrementing IDs when not specified',
    ),
  );
  test(
    'combined crop and sub-cell offset',
    () => verifyKittyGraphicsPlaywrightCase(
      'Larger image (200x100 multicolor PNG) Pixel '
      'verification combined crop and sub-cell offset',
    ),
  );
}
