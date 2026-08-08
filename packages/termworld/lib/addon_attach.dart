/// WebSocket transport addon.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:termworld/src/addons/managed_addon.dart';
import 'package:termworld/src/core/terminal.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Pipes terminal input and output through a WebSocket channel.
final class AttachAddon extends ManagedTerminalAddon {
  /// Creates an attachment. Input is sent to the socket when [bidirectional]
  /// is true.
  AttachAddon(this.socket, {this.bidirectional = true});

  /// Connected socket.
  final WebSocketChannel socket;

  /// Whether terminal user input is written to [socket].
  final bool bidirectional;

  StreamSubscription<Object?>? _subscription;
  _AttachSocketState _socketState = _AttachSocketState.connecting;

  @override
  void onActivate(Terminal terminal) {
    unawaited(
      socket.ready.then(
        (_) {
          if (!isDisposed) _socketState = _AttachSocketState.open;
        },
        onError: (Object _) {
          _socketState = _AttachSocketState.closed;
          dispose();
        },
      ),
    );
    if (bidirectional) {
      own(terminal.onData.listen(_send));
      own(
        terminal.onBinary.listen((data) {
          _send(
            Uint8List.fromList(
              data.codeUnits.map((value) => value & 0xff).toList(),
            ),
          );
        }),
      );
    }
    _subscription = socket.stream.listen(
      (event) {
        if (event is String || event is Uint8List) {
          terminal.write(event as Object);
        } else if (event is List<int>) {
          terminal.write(Uint8List.fromList(event));
        }
      },
      onError: (_) {
        _socketState = _AttachSocketState.closed;
        dispose();
      },
      onDone: () {
        _socketState = _AttachSocketState.closed;
        dispose();
      },
    );
  }

  void _send(Object data) {
    switch (_socketState) {
      case _AttachSocketState.open:
        socket.sink.add(data);
      case _AttachSocketState.connecting:
        throw StateError('Attach addon was loaded before socket was open');
      case _AttachSocketState.closed:
        throw StateError('Attach addon socket is closed');
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}

enum _AttachSocketState { connecting, open, closed }
