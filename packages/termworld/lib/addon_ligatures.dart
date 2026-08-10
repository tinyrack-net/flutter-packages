/// Programming ligature addon.
library;

import 'dart:async';

import 'package:termworld/src/addons/ligature_font.dart';
import 'package:termworld/src/addons/ligature_font_loader.dart';
import 'package:vtworld/vtworld.dart';

enum _LigatureFontLoadingState { unloaded, loading, loaded, failed }

/// Finds common programming ligatures and joins them for shaping.
final class LigaturesAddon extends ManagedTerminalAddon {
  /// Creates a ligature addon.
  LigaturesAddon({
    List<String>? fallbackLigatures,
    this.fontFeatureSettings = '"calt" on',
  }) : fallbackLigatures = List<String>.of(
         fallbackLigatures ?? _defaults,
       )..sort((left, right) => right.length.compareTo(left.length));

  /// Fallback sequences when font metadata is unavailable.
  final List<String> fallbackLigatures;

  /// OpenType feature settings applied by capable renderers.
  final String fontFeatureSettings;

  int? _joinerId;
  String? _currentFontFamily;
  TerminalLigatureFont? _font;
  _LigatureFontLoadingState _loadingState = _LigatureFontLoadingState.unloaded;

  @override
  void onActivate(Terminal terminal) {
    _joinerId = terminal.registerCharacterJoiner((text) {
      final family = terminal.options.fontFamily;
      if (family.isNotEmpty &&
          (_loadingState == _LigatureFontLoadingState.unloaded ||
              _currentFontFamily != family)) {
        _font = null;
        _loadingState = _LigatureFontLoadingState.loading;
        _currentFontFamily = family;
        final requestedFamily = family;
        unawaited(
          loadTerminalLigatureFont(requestedFamily, 100000)
              .then((loaded) {
                if (!isActive ||
                    terminal.options.fontFamily != requestedFamily) {
                  return;
                }
                _loadingState = _LigatureFontLoadingState.loaded;
                _font = loaded;
                if (loaded != null) terminal.refresh(0, terminal.rows - 1);
              })
              .catchError((Object error) {
                if (isActive &&
                    terminal.options.fontFamily == requestedFamily) {
                  _loadingState = _LigatureFontLoadingState.failed;
                  _font = null;
                }
              }),
        );
      }
      if (_loadingState == _LigatureFontLoadingState.loaded && _font != null) {
        return <TerminalCharacterJoin>[
          for (final range in _font!.findLigatureRanges(text))
            TerminalCharacterJoin(range.$1, range.$2),
        ];
      }
      return _fallbackRanges(text);
    });
  }

  List<TerminalCharacterJoin> _fallbackRanges(String text) {
    final result = <TerminalCharacterJoin>[];
    for (var index = 0; index < text.length; index++) {
      for (final ligature in fallbackLigatures) {
        if (!text.startsWith(ligature, index)) continue;
        result.add(TerminalCharacterJoin(index, index + ligature.length));
        index += ligature.length - 1;
        break;
      }
    }
    return result;
  }

  @override
  void dispose() {
    if (isDisposed) return;
    final joinerId = _joinerId;
    if (joinerId != null && isActive) {
      terminal.deregisterCharacterJoiner(joinerId);
    }
    _joinerId = null;
    _currentFontFamily = null;
    _font = null;
    _loadingState = _LigatureFontLoadingState.unloaded;
    super.dispose();
  }

  static const List<String> _defaults = <String>[
    '<--',
    '<---',
    '<<-',
    '<-',
    '->',
    '->>',
    '-->',
    '--->',
    '<==',
    '<===',
    '<<=',
    '<=',
    '=>',
    '=>>',
    '==>',
    '===>',
    '>=',
    '>>=',
    '<->',
    '<-->',
    '<--->',
    '<---->',
    '<=>',
    '<==>',
    '<===>',
    '<====>',
    '::',
    ':::',
    '<~~',
    '</',
    '</>',
    '/>',
    '~~>',
    '==',
    '!=',
    '/=',
    '~=',
    '<>',
    '===',
    '!==',
    '!===',
    '<:',
    ':=',
    '*=',
    '*+',
    '<*',
    '<*>',
    '*>',
    '<|',
    '<|>',
    '|>',
    '+*',
    '=*',
    '=:',
    ':>',
    '/*',
    '*/',
    '+++',
    '<!--',
    '<!---',
  ];
}
