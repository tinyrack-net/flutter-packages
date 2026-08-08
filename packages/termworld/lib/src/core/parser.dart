import 'dart:async';

import 'package:termworld/src/core/disposable.dart';

/// Identifies a CSI, DCS, ESC, or APC function.
final class TerminalFunctionIdentifier {
  /// Creates and validates an xterm function identifier.
  const TerminalFunctionIdentifier({
    required this.finalByte,
    this.prefix = '',
    this.intermediates = '',
  });

  /// xterm-compatible `prefix` API.
  final String prefix;

  /// xterm-compatible `intermediates` API.
  final String intermediates;

  /// xterm-compatible `finalByte` API.
  final String finalByte;

  /// xterm-compatible `key` API.
  String get key => '$prefix|$intermediates|$finalByte';
}

/// One primary parameter or a colon-separated parameter group.
typedef TerminalParameter = Object;

/// xterm-compatible `TerminalCsiHandler` API.
typedef TerminalCsiHandler =
    FutureOr<bool> Function(
      List<TerminalParameter> parameters,
    );

/// xterm-compatible `TerminalDcsHandler` API.
typedef TerminalDcsHandler =
    FutureOr<bool> Function(
      String data,
      List<TerminalParameter> parameters,
    );

/// xterm-compatible `Function` API.
typedef TerminalEscHandler = FutureOr<bool> Function();

/// xterm-compatible `Function` API.
typedef TerminalOscHandler = FutureOr<bool> Function(String data);

/// xterm-compatible `Function` API.
typedef TerminalApcHandler = FutureOr<bool> Function(String data);

/// Custom parser handler registry with xterm's newest-handler-first ordering.
final class TerminalParser implements Disposable {
  static const int _maximumPayload = 10000000;

  final Map<String, List<TerminalCsiHandler>> _csi =
      <String, List<TerminalCsiHandler>>{};
  final Map<String, List<TerminalDcsHandler>> _dcs =
      <String, List<TerminalDcsHandler>>{};
  final Map<String, List<TerminalEscHandler>> _esc =
      <String, List<TerminalEscHandler>>{};
  final Map<int, List<TerminalOscHandler>> _osc =
      <int, List<TerminalOscHandler>>{};
  final Map<String, List<TerminalApcHandler>> _apc =
      <String, List<TerminalApcHandler>>{};
  String _pending = '';
  bool _isDisposed = false;

  /// xterm-compatible `registerCsiHandler` API.
  Disposable registerCsiHandler(
    TerminalFunctionIdentifier identifier,
    TerminalCsiHandler handler,
  ) => _register(_csi, _validate(identifier, csiOrDcs: true).key, handler);

  /// xterm-compatible `registerDcsHandler` API.
  Disposable registerDcsHandler(
    TerminalFunctionIdentifier identifier,
    TerminalDcsHandler handler,
  ) => _register(_dcs, _validate(identifier, csiOrDcs: true).key, handler);

  /// xterm-compatible `registerEscHandler` API.
  Disposable registerEscHandler(
    TerminalFunctionIdentifier identifier,
    TerminalEscHandler handler,
  ) => _register(_esc, _validate(identifier).key, handler);

  /// xterm-compatible `registerOscHandler` API.
  Disposable registerOscHandler(int identifier, TerminalOscHandler handler) {
    if (identifier < 0) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'must be non-negative',
      );
    }
    return _register(_osc, identifier, handler);
  }

  /// xterm-compatible `registerApcHandler` API.
  Disposable registerApcHandler(
    TerminalFunctionIdentifier identifier,
    TerminalApcHandler handler,
  ) => _register(_apc, _validate(identifier).key, handler);

  TerminalFunctionIdentifier _validate(
    TerminalFunctionIdentifier identifier, {
    bool csiOrDcs = false,
  }) {
    if (identifier.finalByte.length != 1) {
      throw ArgumentError.value(
        identifier.finalByte,
        'finalByte',
        'must contain one character',
      );
    }
    final finalCode = identifier.finalByte.codeUnitAt(0);
    final minimum = csiOrDcs ? 0x40 : 0x30;
    if (finalCode < minimum || finalCode > 0x7e) {
      throw ArgumentError.value(identifier.finalByte, 'finalByte');
    }
    if (identifier.prefix.length > 1 ||
        (identifier.prefix.isNotEmpty &&
            !_inRange(identifier.prefix.codeUnitAt(0), 0x3c, 0x3f))) {
      throw ArgumentError.value(identifier.prefix, 'prefix');
    }
    if (identifier.intermediates.length > 2 ||
        identifier.intermediates.codeUnits.any(
          (code) => !_inRange(code, 0x20, 0x2f),
        )) {
      throw ArgumentError.value(identifier.intermediates, 'intermediates');
    }
    return identifier;
  }

  static bool _inRange(int value, int minimum, int maximum) =>
      value >= minimum && value <= maximum;

  Disposable _register<K, H>(Map<K, List<H>> registry, K key, H handler) {
    if (_isDisposed) throw StateError('TerminalParser has been disposed');
    final handlers = registry.putIfAbsent(key, () => <H>[]);
    // Registration and later callback removal intentionally span lifetimes.
    // ignore: cascade_invocations
    handlers.add(handler);
    return CallbackDisposable(() {
      handlers.remove(handler);
      if (handlers.isEmpty) registry.remove(key);
    });
  }

  /// Filters handled custom sequences and preserves incomplete input chunks.
  Future<String> filter(String chunk) async {
    final output = StringBuffer();
    await process(chunk, output.write);
    return output.toString();
  }

  /// Parses [chunk], emitting terminal input in stream order around handlers.
  Future<void> process(
    String chunk,
    FutureOr<void> Function(String data) emit,
  ) async {
    if (_isDisposed) throw StateError('TerminalParser has been disposed');
    final source = '$_pending${_normalizeC1(chunk)}';
    _pending = '';
    var index = 0;
    while (index < source.length) {
      final escape = source.indexOf('\u001b', index);
      if (escape < 0) {
        await emit(source.substring(index));
        break;
      }
      if (escape > index) await emit(source.substring(index, escape));
      final parsed = await _parseAt(source, escape, emit);
      if (parsed == null) {
        _pending = source.substring(escape);
        break;
      }
      if (!parsed.handled) await emit(parsed.sequence);
      index = parsed.end;
    }
  }

  String _normalizeC1(String source) {
    StringBuffer? result;
    var copied = 0;
    for (var index = 0; index < source.length; index++) {
      final replacement = switch (source.codeUnitAt(index)) {
        0x90 => '\u001bP',
        0x98 => '\u001bX',
        0x9b => '\u001b[',
        0x9c => '\u001b\\',
        0x9d => '\u001b]',
        0x9e => '\u001b^',
        0x9f => '\u001b_',
        _ => null,
      };
      if (replacement == null) continue;
      (result ??= StringBuffer())
        ..write(source.substring(copied, index))
        ..write(replacement);
      copied = index + 1;
    }
    if (result == null) return source;
    result.write(source.substring(copied));
    return result.toString();
  }

  Future<_ParsedSequence?> _parseAt(
    String source,
    int start,
    FutureOr<void> Function(String data) emit,
  ) async {
    if (start + 1 >= source.length) return null;
    final introducer = source.codeUnitAt(start + 1);
    final parsed = await switch (introducer) {
      0x5b => _parseCsi(source, start, emit),
      0x5d => _parseOsc(source, start),
      0x50 => _parseDcs(source, start),
      0x5f => _parseApc(source, start),
      _ => _parseEsc(source, start, emit),
    };
    final searchEnd = parsed?.end ?? source.length;
    for (var index = start + 1; index < searchEnd; index++) {
      final code = source.codeUnitAt(index);
      if (code == 0x18 || code == 0x1a) {
        return _ParsedSequence(
          source.substring(start, index + 1),
          index + 1,
          handled: true,
        );
      }
    }
    return parsed;
  }

  Future<_ParsedSequence?> _parseCsi(
    String source,
    int start,
    FutureOr<void> Function(String data) emit,
  ) async {
    final body = StringBuffer();
    final executed = StringBuffer();
    var finalIndex = -1;
    for (var index = start + 2; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (code == 0x18 || code == 0x1a) {
        if (executed.isNotEmpty) await emit(executed.toString());
        return _ParsedSequence(
          source.substring(start, index + 1),
          index + 1,
          handled: true,
        );
      }
      if (code == 0x1b) {
        if (executed.isNotEmpty) await emit(executed.toString());
        return _ParsedSequence(
          source.substring(start, index),
          index,
          handled: true,
        );
      }
      if (code >= 0x40 && code <= 0x7e) {
        finalIndex = index;
        break;
      }
      if (_isExecutable(code)) {
        executed.writeCharCode(code);
      } else if (code != 0x7f) {
        body.writeCharCode(code);
      }
    }
    if (finalIndex < 0) return null;
    if (executed.isNotEmpty) await emit(executed.toString());
    final bodyValue = body.toString();
    final identifier = _identifier(bodyValue, source[finalIndex]);
    final handled = await _callNewest(
      _csi[identifier.key],
      (handler) => handler(_parameters(_parameterPart(bodyValue))),
    );
    return _ParsedSequence(
      '\u001b[$bodyValue${source[finalIndex]}',
      finalIndex + 1,
      handled: handled,
    );
  }

  bool _isExecutable(int code) =>
      code <= 0x17 || code == 0x19 || code >= 0x1c && code <= 0x1f;

  Future<_ParsedSequence?> _parseOsc(String source, int start) async {
    final terminator = _stringTerminator(
      source,
      start + 2,
      bellTerminates: true,
    );
    if (terminator == null) return null;
    final body = _stringPayload(
      source.substring(start + 2, terminator.start),
      _StringPayloadKind.osc,
    );
    final separator = body.indexOf(';');
    final identifier = int.tryParse(
      separator < 0 ? body : body.substring(0, separator),
    );
    final data = separator < 0 ? '' : body.substring(separator + 1);
    final handled =
        terminator.success &&
        data.length <= _maximumPayload &&
        !(identifier == null) &&
        await _callNewest(_osc[identifier], (handler) => handler(data));
    return _ParsedSequence(
      source.substring(start, terminator.end),
      terminator.end,
      handled: handled,
    );
  }

  Future<_ParsedSequence?> _parseDcs(String source, int start) async {
    final finalIndex = _findFinal(source, start + 2, 0x40);
    if (finalIndex < 0) return null;
    final terminator = _stringTerminator(source, finalIndex + 1);
    if (terminator == null) return null;
    final header = source.substring(start + 2, finalIndex);
    final identifier = _identifier(header, source[finalIndex]);
    final data = _stringPayload(
      source.substring(finalIndex + 1, terminator.start),
      _StringPayloadKind.dcs,
    );
    final handled =
        terminator.success &&
        data.length <= _maximumPayload &&
        await _callNewest(
          _dcs[identifier.key],
          (handler) => handler(data, _parameters(_parameterPart(header))),
        );
    return _ParsedSequence(
      source.substring(start, terminator.end),
      terminator.end,
      handled: handled,
    );
  }

  Future<_ParsedSequence?> _parseApc(String source, int start) async {
    final finalIndex = _findFinal(source, start + 2, 0x30);
    if (finalIndex < 0) return null;
    final terminator = _stringTerminator(source, finalIndex + 1);
    if (terminator == null) return null;
    final header = source.substring(start + 2, finalIndex);
    final identifier = _identifier(header, source[finalIndex]);
    final data = _stringPayload(
      source.substring(finalIndex + 1, terminator.start),
      _StringPayloadKind.apc,
    );
    final handled =
        terminator.success &&
        data.length <= _maximumPayload &&
        await _callNewest(_apc[identifier.key], (handler) => handler(data));
    return _ParsedSequence(
      source.substring(start, terminator.end),
      terminator.end,
      handled: handled,
    );
  }

  Future<_ParsedSequence?> _parseEsc(
    String source,
    int start,
    FutureOr<void> Function(String data) emit,
  ) async {
    final body = StringBuffer();
    final executed = StringBuffer();
    var finalIndex = -1;
    for (var index = start + 1; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (code == 0x18 || code == 0x1a) {
        if (executed.isNotEmpty) await emit(executed.toString());
        await emit(source[index]);
        return _ParsedSequence(
          source.substring(start, index + 1),
          index + 1,
          handled: true,
        );
      }
      if (code == 0x1b) {
        if (executed.isNotEmpty) await emit(executed.toString());
        return _ParsedSequence(
          source.substring(start, index),
          index,
          handled: true,
        );
      }
      if (code >= 0x30 && code <= 0x7e) {
        finalIndex = index;
        break;
      }
      if (_isExecutable(code)) {
        executed.writeCharCode(code);
      } else if (code >= 0x20 && code <= 0x2f) {
        body.writeCharCode(code);
      }
    }
    if (finalIndex < 0) return null;
    if (executed.isNotEmpty) await emit(executed.toString());
    final bodyValue = body.toString();
    final identifier = TerminalFunctionIdentifier(
      intermediates: bodyValue,
      finalByte: source[finalIndex],
    );
    final handled = await _callNewest(
      _esc[identifier.key],
      (handler) => handler(),
    );
    return _ParsedSequence(
      '\u001b$bodyValue${source[finalIndex]}',
      finalIndex + 1,
      handled: handled,
    );
  }

  int _findFinal(String source, int start, int minimum) {
    for (var index = start; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (code >= minimum && code <= 0x7e) return index;
    }
    return -1;
  }

  _Terminator? _stringTerminator(
    String source,
    int start, {
    bool bellTerminates = false,
  }) {
    for (var index = start; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (bellTerminates && code == 0x07) {
        return _Terminator(index, index + 1, success: true);
      }
      if (code == 0x18 || code == 0x1a) {
        return _Terminator(index, index + 1, success: false);
      }
      if (code == 0x1b) {
        if (index + 1 < source.length && source.codeUnitAt(index + 1) == 0x5c) {
          return _Terminator(index, index + 2, success: true);
        }
        // ESC ends the string successfully and starts a fresh escape
        // sequence. Leave it unconsumed so the outer parser processes it.
        return _Terminator(index, index, success: true);
      }
    }
    return null;
  }

  String _stringPayload(String source, _StringPayloadKind kind) {
    StringBuffer? result;
    var copied = 0;
    for (var index = 0; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      final ignored = switch (kind) {
        _StringPayloadKind.osc => _isExecutable(code),
        _StringPayloadKind.dcs => code == 0x7f,
        _StringPayloadKind.apc =>
          code == 0x7f ||
              code <= 0x07 ||
              code >= 0x0e && code <= 0x17 ||
              code == 0x19 ||
              code >= 0x1c && code <= 0x1f,
      };
      if (!ignored) continue;
      (result ??= StringBuffer()).write(source.substring(copied, index));
      copied = index + 1;
    }
    if (result == null) return source;
    result.write(source.substring(copied));
    return result.toString();
  }

  TerminalFunctionIdentifier _identifier(String body, String finalByte) {
    var prefix = '';
    var cursor = 0;
    if (body.isNotEmpty && _inRange(body.codeUnitAt(0), 0x3c, 0x3f)) {
      prefix = body[0];
      cursor = 1;
    }
    final intermediates = StringBuffer();
    for (; cursor < body.length; cursor++) {
      final code = body.codeUnitAt(cursor);
      if (_inRange(code, 0x20, 0x2f)) intermediates.writeCharCode(code);
    }
    return TerminalFunctionIdentifier(
      prefix: prefix,
      intermediates: intermediates.toString(),
      finalByte: finalByte,
    );
  }

  String _parameterPart(String body) {
    final result = StringBuffer();
    for (final code in body.codeUnits) {
      if ((code >= 0x30 && code <= 0x3b) || code == 0x3a) {
        result.writeCharCode(code);
      }
    }
    return result.toString();
  }

  List<TerminalParameter> _parameters(String source) {
    if (source.isEmpty) return <TerminalParameter>[0];
    const maximumParameters = 32;
    const maximumSubParameters = 32;
    final result = <TerminalParameter>[];
    var subParameterCount = 0;
    for (final parameter in source.split(';').take(maximumParameters)) {
      final values = parameter.split(':');
      result.add(_parameterValue(values.first, 0));
      if (values.length == 1 || subParameterCount >= maximumSubParameters) {
        continue;
      }
      final remaining = maximumSubParameters - subParameterCount;
      final subParameters = values
          .skip(1)
          .take(remaining)
          .map((value) => _parameterValue(value, -1))
          .toList(growable: false);
      subParameterCount += subParameters.length;
      if (subParameters.isNotEmpty) result.add(subParameters);
    }
    return result;
  }

  int _parameterValue(String source, int fallback) =>
      (int.tryParse(source) ?? fallback).clamp(-1, 0x7fffffff);

  Future<bool> _callNewest<H>(
    List<H>? handlers,
    FutureOr<bool> Function(H handler) call,
  ) async {
    if (handlers == null) return false;
    for (final handler in List<H>.of(handlers).reversed) {
      if (await call(handler)) return true;
    }
    return false;
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _pending = '';
    _csi.clear();
    _dcs.clear();
    _esc.clear();
    _osc.clear();
    _apc.clear();
  }
}

final class _ParsedSequence {
  const _ParsedSequence(this.sequence, this.end, {required this.handled});

  final String sequence;
  final int end;
  final bool handled;
}

final class _Terminator {
  const _Terminator(this.start, this.end, {required this.success});

  final int start;
  final int end;
  final bool success;
}

enum _StringPayloadKind { osc, dcs, apc }
