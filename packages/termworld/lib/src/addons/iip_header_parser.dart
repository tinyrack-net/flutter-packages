import 'dart:convert';
import 'dart:typed_data';

/// States of the iTerm2 inline-image header parser.
enum IipHeaderState {
  /// Reading the sequence marker.
  start,

  /// Parsing was aborted by invalid input.
  abort,

  /// Reading a field name.
  key,

  /// Reading a field value.
  value,

  /// Header parsing completed.
  end,
}

/// Type of iTerm2 inline-image sequence.
enum IipSequenceType {
  /// Invalid sequence.
  invalid,

  /// Single-part file.
  file,

  /// Multipart file header.
  multipartFile,

  /// Multipart file payload part.
  filePart,

  /// Multipart file terminator.
  fileEnd,

  /// Cell-size report request.
  reportCellSize,
}

/// Streaming parser for iTerm2 inline-image headers.
final class IipHeaderParser {
  static const int _maxFieldCharacters = 1024;
  static final Uint32List _fileMarker = _ascii('File');
  static final Uint32List _multipartFileMarker = _ascii('MultipartFile');
  static final Uint32List _filePartMarker = _ascii('FilePart');
  static final Uint32List _fileEndMarker = _ascii('FileEnd');
  static final Uint32List _reportCellSizeMarker = _ascii('ReportCellSize');

  final Uint32List _buffer = Uint32List(_maxFieldCharacters);
  int _position = 0;
  String _key = '';

  /// Current parser state.
  IipHeaderState state = IipHeaderState.start;

  /// Parsed fields, including the `type` field.
  Map<String, Object?> fields = <String, Object?>{};

  /// Restores the initial parser state.
  void reset() {
    _buffer.fillRange(0, _buffer.length, 0);
    state = IipHeaderState.start;
    _position = 0;
    fields = <String, Object?>{};
    _key = '';
  }

  /// Ends an unterminated marker or multipart header.
  int end() {
    if (state == IipHeaderState.start) {
      if (_position == _fileEndMarker.length &&
          _matches(_fileEndMarker, _position)) {
        fields['type'] = IipSequenceType.fileEnd;
        state = IipHeaderState.end;
        return 0;
      }
      if (_position == _reportCellSizeMarker.length &&
          _matches(_reportCellSizeMarker, _position)) {
        fields['type'] = IipSequenceType.reportCellSize;
        state = IipHeaderState.end;
        return 0;
      }
      return _abort();
    }
    if (state == IipHeaderState.end) return 0;
    if (state == IipHeaderState.value &&
        fields['type'] == IipSequenceType.multipartFile) {
      if (!_storeValue(_position)) return _abort();
      state = IipHeaderState.end;
      return 0;
    }
    return _abort();
  }

  /// Parses code points in `[start, end)`.
  ///
  /// Returns the consumed position on completion, `-1` on abort, or `-2`
  /// when more input is needed.
  int parse(Uint32List data, int start, int end) {
    var currentState = state;
    var position = _position;
    if (currentState == IipHeaderState.abort ||
        currentState == IipHeaderState.end) {
      return -1;
    }
    if (currentState == IipHeaderState.start && position > 14) return -1;
    for (var index = start; index < end; index++) {
      final code = data[index];
      switch (code) {
        case 59:
          if (!_storeValue(position)) return _abort();
          currentState = IipHeaderState.key;
          position = 0;
        case 61:
          if (currentState == IipHeaderState.start) {
            if (_buffer[0] == 70) {
              if (!_startsWith(_fileMarker, position)) return _abort();
              fields['type'] = IipSequenceType.file;
              if (position == _filePartMarker.length) {
                if (!_startsWith(_filePartMarker, position)) return _abort();
                fields['type'] = IipSequenceType.filePart;
                state = IipHeaderState.end;
                return index + 1;
              }
            } else if (_buffer[0] == 77) {
              if (!_startsWith(_multipartFileMarker, position)) return _abort();
              fields['type'] = IipSequenceType.multipartFile;
            } else {
              return _abort();
            }
            currentState = IipHeaderState.key;
            position = 0;
          } else if (currentState == IipHeaderState.key) {
            if (!_storeKey(position)) return _abort();
            currentState = IipHeaderState.value;
            position = 0;
          } else if (currentState == IipHeaderState.value) {
            if (position >= _maxFieldCharacters) return _abort();
            _buffer[position++] = code;
          }
        case 58:
          if (currentState == IipHeaderState.value && !_storeValue(position)) {
            return _abort();
          }
          state = IipHeaderState.end;
          _position = position;
          return index + 1;
        default:
          if (position >= _maxFieldCharacters) return _abort();
          _buffer[position++] = code;
      }
    }
    state = currentState;
    _position = position;
    return -2;
  }

  int _abort() {
    fields['type'] = IipSequenceType.invalid;
    state = IipHeaderState.abort;
    return -1;
  }

  bool _matches(Uint32List marker, int length) {
    if (length != marker.length) return false;
    for (var index = 0; index < marker.length; index++) {
      if (_buffer[index] != marker[index]) return false;
    }
    return true;
  }

  bool _startsWith(Uint32List marker, int length) {
    if (length < marker.length) return false;
    for (var index = 0; index < marker.length; index++) {
      if (_buffer[index] != marker[index]) return false;
    }
    return true;
  }

  bool _storeKey(int length) {
    final key = String.fromCharCodes(_buffer, 0, length);
    if (key.isEmpty) return false;
    _key = key;
    fields[key] = null;
    return true;
  }

  bool _storeValue(int length) {
    if (_key.isEmpty) return false;
    final value = Uint32List.fromList(_buffer.sublist(0, length));
    try {
      fields[_key] = switch (_key) {
        'inline' || 'size' || 'preserveAspectRatio' => _toInt(value),
        'name' => _toName(value),
        'width' || 'height' => _toSize(value),
        _ => value,
      };
      return true;
    } on Object {
      return false;
    }
  }

  static int _toInt(Uint32List data) {
    var value = 0;
    for (final code in data) {
      if (code < 48 || code > 57) throw const FormatException('illegal char');
      value = value * 10 + code - 48;
    }
    return value;
  }

  static String _toSize(Uint32List data) {
    final value = String.fromCharCodes(data);
    if (!RegExp(r'^(?:auto|\d+(?:(?:px)|%)?)$').hasMatch(value)) {
      throw const FormatException('illegal size');
    }
    return value;
  }

  static String _toName(Uint32List data) {
    final encoded = String.fromCharCodes(data);
    final normalized = base64.normalize(encoded);
    return utf8.decode(base64.decode(normalized), allowMalformed: true);
  }

  static Uint32List _ascii(String value) =>
      Uint32List.fromList(value.codeUnits);
}
