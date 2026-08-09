import 'package:flutter_test/flutter_test.dart';
import 'package:termworld/src/addons/webgl_glyph_renderer.dart';
import 'package:termworld/src/addons/webgl_rectangle_renderer.dart';
import 'package:termworld/src/addons/webgl_texture_atlas.dart';
import 'package:termworld/src/addons/webgl_utils.dart';
import 'package:termworld/termworld_headless.dart';

/// Executes one pinned xterm WebGL atlas Playwright regression.
Future<void> verifyWebglAtlasPlaywrightCase(String fullName) async {
  if (fullName.contains('cannot be reduced by merging')) {
    _verifyPageCapEviction();
    return;
  }
  if (fullName.contains('oversized glyph page')) {
    _verifyOversizedPageEviction();
    return;
  }
  if (fullName.contains('after shared atlas page merges')) {
    _verifySharedAtlasMerge();
    return;
  }
  if (fullName.contains('after terminal A clears')) {
    _verifySharedAtlasClear();
    return;
  }
  if (fullName.contains('alternate-buffer redraws')) {
    await _verifyAlternateBufferStress();
    return;
  }
  throw StateError('unhandled WebGL atlas case: $fullName');
}

void _verifyPageCapEviction() {
  var removals = 0;
  final atlas = TerminalWebglTextureAtlas(
    maxAtlasPages: 4,
    textureSize: 32,
    maxTextureSize: 32,
    onRemovePage: (_) => removals++,
  );
  addTearDown(atlas.dispose);
  _fillToPageCount(atlas, 4);
  final before = atlas.pageLayoutVersion;
  for (var index = 0; removals == 0; index++) {
    if (index > 100) throw StateError('full page cap did not evict');
    atlas.addSyntheticGlyph('force-eviction-$index');
  }
  expect(removals, greaterThanOrEqualTo(4));
  expect(atlas.pageLayoutVersion, greaterThan(before));
  expect(atlas.pages, hasLength(1));
  final stable = atlas.pageLayoutVersion;
  expect(atlas.addSyntheticGlyph('force-eviction-0'), isNotNull);
  expect(atlas.pageLayoutVersion, stable);
}

void _verifyOversizedPageEviction() {
  var removals = 0;
  var additions = 0;
  final atlas = TerminalWebglTextureAtlas(
    maxAtlasPages: 4,
    textureSize: 32,
    maxTextureSize: 64,
    onAddPage: (_) => additions++,
    onRemovePage: (_) => removals++,
  );
  addTearDown(atlas.dispose);
  _fillToPageCount(atlas, 4);
  expect(atlas.overflowPageCreated, isFalse);
  final before = atlas.pageLayoutVersion;
  final oversized = atlas.addSyntheticGlyph('wide', width: 48);
  expect(atlas.overflowPageCreated, isTrue);
  expect(oversized.texturePage, 0);
  expect(removals, greaterThanOrEqualTo(4));
  expect(atlas.pageLayoutVersion, greaterThan(before));
  expect(atlas.pages.length, lessThanOrEqualTo(4));
  expect(additions, greaterThanOrEqualTo(5));
  final stable = atlas.pageLayoutVersion;
  expect(atlas.addSyntheticGlyph('wide', width: 48), same(oversized));
  expect(atlas.pageLayoutVersion, stable);
}

void _verifySharedAtlasMerge() {
  final cache = TerminalCharAtlasCache<TerminalWebglTextureAtlas>();
  final ownerA = Object();
  final ownerB = Object();
  final config = _config();
  final atlasA = cache.acquire(
    ownerA,
    config,
    () => TerminalWebglTextureAtlas(
      maxAtlasPages: 4,
      textureSize: 32,
      maxTextureSize: 64,
    ),
  );
  final atlasB = cache.acquire(
    ownerB,
    config,
    () => throw StateError('compatible atlas must be shared'),
  );
  addTearDown(() {
    cache
      ..removeOwner(ownerA)
      ..removeOwner(ownerB);
  });
  expect(atlasB, same(atlasA));
  final header = atlasB.addSyntheticGlyph('HEADER_REF');
  final rendererB = _renderer()..setAtlas(atlasB);
  expect(rendererB.beginFrame(), isTrue);
  expect(rendererB.beginFrame(), isFalse);
  _fillToPageCount(atlasA, 4);
  final before = atlasA.pageLayoutVersion;
  for (var index = 0; atlasA.pageLayoutVersion == before; index++) {
    if (index > 100) throw StateError('full shared atlas did not merge');
    atlasA.addSyntheticGlyph('trigger-merge-$index');
  }
  expect(atlasA.pageLayoutVersion, greaterThan(before));
  expect(rendererB.beginFrame(), isTrue);
  final rebuilt = atlasB.addSyntheticGlyph('HEADER_REF');
  expect(rebuilt.size.x, header.size.x);
  expect(rebuilt.size.y, header.size.y);
  expect(rebuilt.texturePage, lessThan(atlasB.pages.length));
}

void _verifySharedAtlasClear() {
  final atlas = TerminalWebglTextureAtlas(
    textureSize: 32,
    maxTextureSize: 64,
  );
  addTearDown(atlas.dispose);
  final rendererA = _renderer()..setAtlas(atlas);
  final rendererB = _renderer()..setAtlas(atlas);
  final header = atlas.addSyntheticGlyph('HEADER_REF');
  expect(rendererA.beginFrame(), isTrue);
  expect(rendererB.beginFrame(), isTrue);
  expect(rendererB.beginFrame(), isFalse);
  atlas.clearTexture();
  expect(rendererB.beginFrame(), isTrue);
  for (var index = 0; index < 16; index++) {
    atlas.addSyntheticGlyph('replacement-$index');
  }
  final rebuilt = atlas.addSyntheticGlyph('HEADER_REF');
  expect(rebuilt, isNot(same(header)));
  expect(rebuilt.texturePage, lessThan(atlas.pages.length));
}

Future<void> _verifyAlternateBufferStress() async {
  final terminal = Terminal(
    options: TerminalOptions(cols: 40, rows: 12, scrollback: 500),
  );
  final atlas = TerminalWebglTextureAtlas(
    maxAtlasPages: 4,
    textureSize: 32,
    maxTextureSize: 64,
  );
  addTearDown(terminal.dispose);
  addTearDown(atlas.dispose);
  const reference = 'Ref0123456789ABCDEF';
  await terminal.writeAndWait(reference);
  expect(
    terminal.buffer.normal.getLine(0)!.translateToString(trimRight: true),
    reference,
  );
  final renderer = _renderer()
    ..setAtlas(atlas)
    ..beginFrame();
  await terminal.writeAndWait('\x1b[?1049h');
  expect(terminal.buffer.active.type, TerminalBufferType.alternate);
  for (var frame = 0; frame < 30; frame++) {
    await terminal.writeAndWait(
      '\x1b[2J\x1b[Hframe $frame\r\n'
      '${List<String>.filled(8, 'atlas terminal buffer').join('\r\n')}',
    );
    for (var glyph = 0; glyph < 18; glyph++) {
      atlas.addSyntheticGlyph('frame-$frame-glyph-$glyph');
    }
  }
  await terminal.writeAndWait('\x1b[?1049l');
  expect(terminal.buffer.active.type, TerminalBufferType.normal);
  expect(
    terminal.buffer.active.getLine(0)!.translateToString(trimRight: true),
    reference,
  );
  expect(atlas.pages.length, greaterThan(1));
  expect(atlas.pages.length, lessThanOrEqualTo(4));
  expect(renderer.beginFrame(), isTrue);
  for (final code in reference.runes) {
    final glyph = atlas.getGlyph(code, 0, 0, 0);
    expect(glyph.texturePage, lessThan(atlas.pages.length));
  }
}

void _fillToPageCount(TerminalWebglTextureAtlas atlas, int count) {
  for (var index = 0; atlas.pages.length < count; index++) {
    if (index > 10000) throw StateError('atlas did not reach $count pages');
    atlas.addSyntheticGlyph('fill-$count-$index');
  }
}

TerminalWebglGlyphRendererModel _renderer() => TerminalWebglGlyphRendererModel(
  columns: 4,
  rows: 2,
  dimensions: const TerminalWebglGlyphDimensions(
    device: TerminalWebglDeviceDimensions(
      cellWidth: 8,
      cellHeight: 16,
      canvasWidth: 32,
      canvasHeight: 32,
    ),
    characterWidth: 8,
    characterLeft: 0,
    characterTop: 0,
  ),
);

TerminalCharAtlasConfig _config() => const TerminalCharAtlasConfig(
  ansi: <int>[],
  deviceMaxTextureSize: 64,
  deviceCellWidth: 8,
  deviceCellHeight: 16,
  fontSize: 14,
  fontWeight: 400,
  fontWeightBold: 700,
);
