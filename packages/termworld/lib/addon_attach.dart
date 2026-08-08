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

  @override
  void onActivate(Terminal terminal) {
    if (bidirectional) {
      own(terminal.onData.listen(socket.sink.add));
      own(
        terminal.onBinary.listen((data) {
          socket.sink.add(Uint8List.fromList(data.codeUnits));
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
      onError: (_) => dispose(),
      onDone: dispose,
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
