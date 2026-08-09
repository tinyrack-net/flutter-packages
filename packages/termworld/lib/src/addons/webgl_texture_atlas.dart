import 'dart:math' as math;

import 'package:termworld/src/addons/webgl_glyph_renderer.dart';
import 'package:termworld/src/addons/webgl_utils.dart';

/// One owner-independent CPU model of xterm's multi-page texture atlas.
///
/// Browser canvases and GPU textures are adapters over this model. Keeping the
/// packing and invalidation state here makes page merge/eviction observable on
/// every test host without importing `dart:ui` or browser APIs.
final class TerminalWebglTextureAtlas
    implements TerminalWebglGlyphAtlas, TerminalDisposableCharAtlas {
  /// Creates an atlas with xterm's 512px initial page size.
  TerminalWebglTextureAtlas({
    this.maxAtlasPages,
    this.maxTextureSize = 4096,
    this.textureSize = 512,
    this.cellWidth = 8,
    this.cellHeight = 16,
    this.onAddPage,
    this.onRemovePage,
  }) : assert(
         maxAtlasPages == null || maxAtlasPages > 0,
         'maxAtlasPages must be positive',
       ),
       assert(
         maxTextureSize >= textureSize,
         'maxTextureSize must contain a normal atlas page',
       ) {
    _createPage(textureSize);
  }

  /// Optional renderer texture-unit cap used by xterm's regression hooks.
  final int? maxAtlasPages;

  /// Maximum GPU texture dimension.
  final int maxTextureSize;

  /// Normal writable page dimension.
  final int textureSize;

  /// Synthetic glyph cell width used by the CPU packer.
  final int cellWidth;

  /// Synthetic glyph cell height used by the CPU packer.
  final int cellHeight;

  /// Called after a page is appended.
  final void Function(TerminalWebglGlyphAtlasPage page)? onAddPage;

  /// Called before a page is removed.
  final void Function(TerminalWebglGlyphAtlasPage page)? onRemovePage;

  final List<_AtlasPageState> _pageStates = <_AtlasPageState>[];
  final Map<String, TerminalWebglRasterizedGlyph> _glyphs =
      <String, TerminalWebglRasterizedGlyph>{};
  int _pageLayoutVersion = 0;
  int _nextPageVersion = 0;
  bool _disposed = false;
  bool _overflowPageCreated = false;

  @override
  bool get isDisposed => _disposed;

  @override
  int get pageLayoutVersion => _pageLayoutVersion;

  @override
  List<TerminalWebglGlyphAtlasPage> get pages => List.unmodifiable(
    _pageStates.map((page) => page.snapshot),
  );

  /// Whether a glyph wider than a regular page allocated the overflow page.
  bool get overflowPageCreated => _overflowPageCreated;

  /// Current cached glyph count.
  int get glyphCount => _glyphs.length;

  @override
  TerminalWebglRasterizedGlyph getGlyph(
    int code,
    int background,
    int foreground,
    int extended,
  ) => _glyph(
    '$code;$background;$foreground;$extended',
    width: cellWidth,
  );

  @override
  TerminalWebglRasterizedGlyph getCombinedGlyph(
    String characters,
    int background,
    int foreground,
    int extended,
  ) => _glyph(
    '$characters;$background;$foreground;$extended',
    width: math.max(cellWidth, characters.runes.length * cellWidth),
  );

  /// Adds a deterministic synthetic glyph used by atlas conformance tests.
  TerminalWebglRasterizedGlyph addSyntheticGlyph(
    String key, {
    int? width,
    int? height,
  }) => _glyph(
    key,
    width: width ?? cellWidth,
    height: height ?? cellHeight,
  );

  TerminalWebglRasterizedGlyph _glyph(
    String key, {
    required int width,
    int? height,
  }) {
    if (_disposed) throw StateError('TextureAtlas is disposed');
    final cached = _glyphs[key];
    if (cached != null) return cached;
    final resolvedHeight = height ?? cellHeight;
    final page = width > textureSize || resolvedHeight > textureSize
        ? _overflowPage(width, resolvedHeight)
        : _writablePage(width, resolvedHeight);
    final x = page.cursorX;
    final y = page.cursorY;
    page.allocate(width, resolvedHeight);
    final pageIndex = _pageStates.indexOf(page);
    final glyph = TerminalWebglRasterizedGlyph(
      offset: const TerminalWebglGlyphVector(0, 0),
      size: TerminalWebglGlyphVector(
        width.toDouble(),
        resolvedHeight.toDouble(),
      ),
      texturePage: pageIndex,
      texturePositionClipSpace: TerminalWebglGlyphVector(
        x / page.size,
        y / page.size,
      ),
      sizeClipSpace: TerminalWebglGlyphVector(
        width / page.size,
        resolvedHeight / page.size,
      ),
    );
    _glyphs[key] = glyph;
    page.keys.add(key);
    return glyph;
  }

  _AtlasPageState _writablePage(int width, int height) {
    for (final page in _pageStates) {
      if (!page.overflow && page.canAllocate(width, height)) return page;
    }
    return _createNormalPage();
  }

  _AtlasPageState _overflowPage(int width, int height) {
    for (final page in _pageStates) {
      if (page.overflow && page.canAllocate(width, height)) return page;
    }
    final cap = maxAtlasPages;
    if (cap != null && _pageStates.length >= cap) _evictAllPages();
    _overflowPageCreated = true;
    return _createPage(maxTextureSize, overflow: true);
  }

  _AtlasPageState _createNormalPage() {
    final cap = maxAtlasPages;
    if (cap != null && _pageStates.length >= math.max(4, cap)) {
      final candidates =
          _pageStates
              .where(
                (page) => !page.overflow && page.size * 2 <= maxTextureSize,
              )
              .toList()
            ..sort((a, b) {
              final size = b.size.compareTo(a.size);
              return size != 0 ? size : b.used.compareTo(a.used);
            });
      List<_AtlasPageState>? merging;
      for (var index = 0; index + 3 < candidates.length; index++) {
        final group = candidates.sublist(index, index + 4);
        if (group.every((page) => page.size == group.first.size)) {
          merging = group;
          break;
        }
      }
      if (merging == null) {
        _evictAllPages();
      } else {
        _mergePages(merging);
      }
    }
    return _createPage(textureSize);
  }

  void _mergePages(List<_AtlasPageState> merging) {
    final oldGlyphs = <String, TerminalWebglRasterizedGlyph>{};
    for (final page in merging) {
      for (final key in page.keys) {
        final glyph = _glyphs[key];
        if (glyph != null) oldGlyphs[key] = glyph;
      }
      onRemovePage?.call(page.snapshot);
    }
    _pageStates.removeWhere(merging.contains);
    final merged = _createPage(merging.first.size * 2, notify: false);
    for (final entry in oldGlyphs.entries) {
      final old = entry.value;
      final x = merged.cursorX;
      final y = merged.cursorY;
      final width = old.size.x.toInt();
      final height = old.size.y.toInt();
      merged.allocate(width, height);
      merged.keys.add(entry.key);
      _glyphs[entry.key] = TerminalWebglRasterizedGlyph(
        offset: old.offset,
        size: old.size,
        texturePage: _pageStates.indexOf(merged),
        texturePositionClipSpace: TerminalWebglGlyphVector(
          x / merged.size,
          y / merged.size,
        ),
        sizeClipSpace: TerminalWebglGlyphVector(
          width / merged.size,
          height / merged.size,
        ),
      );
    }
    _pageLayoutVersion++;
    onAddPage?.call(merged.snapshot);
  }

  _AtlasPageState _createPage(
    int size, {
    bool overflow = false,
    bool notify = true,
  }) {
    final page = _AtlasPageState(
      size,
      ++_nextPageVersion,
      overflow: overflow,
    );
    _pageStates.add(page);
    if (notify) onAddPage?.call(page.snapshot);
    return page;
  }

  void _evictAllPages() {
    for (final page in _pageStates) {
      onRemovePage?.call(page.snapshot);
    }
    _pageStates.clear();
    _glyphs.clear();
    _overflowPageCreated = false;
    _pageLayoutVersion++;
  }

  /// Clears shared page contents and invalidates every owner's render model.
  void clearTexture() {
    if (_disposed || _glyphs.isEmpty) return;
    _glyphs.clear();
    for (final page in _pageStates) {
      page.clear(++_nextPageVersion);
    }
    _overflowPageCreated = false;
    _pageLayoutVersion++;
  }

  @override
  void dispose() {
    if (_disposed) return;
    for (final page in _pageStates) {
      onRemovePage?.call(page.snapshot);
    }
    _pageStates.clear();
    _glyphs.clear();
    _disposed = true;
  }
}

final class _AtlasPageState {
  _AtlasPageState(this.size, this.version, {required this.overflow});

  final int size;
  int version;
  final bool overflow;
  final List<String> keys = <String>[];
  int cursorX = 0;
  int cursorY = 0;
  int rowHeight = 0;
  int used = 0;

  TerminalWebglGlyphAtlasPage get snapshot => TerminalWebglGlyphAtlasPage(
    width: size.toDouble(),
    height: size.toDouble(),
    version: version,
  );

  bool canAllocate(int width, int height) {
    if (width > size || height > size) return false;
    if (cursorX + width <= size && cursorY + height <= size) return true;
    return cursorY + rowHeight + height <= size;
  }

  void allocate(int width, int height) {
    if (cursorX + width > size) {
      cursorX = 0;
      cursorY += rowHeight;
      rowHeight = 0;
    }
    cursorX += width;
    rowHeight = math.max(rowHeight, height);
    used += width * height;
    version++;
  }

  void clear(int nextVersion) {
    keys.clear();
    cursorX = 0;
    cursorY = 0;
    rowHeight = 0;
    used = 0;
    version = nextVersion;
  }
}
