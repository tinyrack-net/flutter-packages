/// Programming ligature addon.
library;

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';

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

  @override
  void onActivate(Terminal terminal) {
    _joinerId = terminal.registerCharacterJoiner((text) {
      final result = <TerminalCharacterJoin>[];
      var index = 0;
      while (index < text.length) {
        String? match;
        for (final ligature in fallbackLigatures) {
          if (text.startsWith(ligature, index)) {
            match = ligature;
            break;
          }
        }
        if (match == null) {
          index++;
        } else {
          result.add(TerminalCharacterJoin(index, index + match.length));
          index += match.length;
        }
      }
      return result;
    });
  }

  @override
  void dispose() {
    final joinerId = _joinerId;
    if (joinerId != null && isActive) {
      terminal.deregisterCharacterJoiner(joinerId);
    }
    _joinerId = null;
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
    '!==',
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
