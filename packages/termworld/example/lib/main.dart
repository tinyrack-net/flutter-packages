import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:termworld/termworld.dart';

void main() => runApp(const TermworldExampleApp());

/// Observable state used by the manual example and Linux black-box IME test.
///
/// This belongs to the example rather than termworld's public library so a
/// production consumer cannot bypass the platform text-input contract.
final class TermworldExampleController extends ChangeNotifier {
  /// Creates an example controller and its terminal engine.
  TermworldExampleController() {
    emulator = TerminalEmulator(onOutput: _recordOutput)
      ..write('\u001b[1;36mtermworld\u001b[0m\r\n한글 IME: ');
  }

  /// Terminal engine rendered by the example.
  late final TerminalEmulator emulator;

  final StringBuffer _output = StringBuffer();

  /// Exact data that termworld would send to a PTY.
  String get output => _output.toString();

  void _recordOutput(String value) {
    _output.write(value);
    notifyListeners();
  }

  /// Clears only the recorded PTY output between manual checks.
  void clearOutput() {
    _output.clear();
    notifyListeners();
  }

  /// Enables or disables DEC bracketed-paste mode.
  void setBracketedPaste({required bool enabled}) {
    emulator.write(enabled ? '\u001b[?2004h' : '\u001b[?2004l');
  }

  /// Reads the real platform clipboard and sends it through terminal paste.
  Future<void> pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) emulator.paste(text);
  }

  @override
  void dispose() {
    emulator.dispose();
    super.dispose();
  }
}

/// Standalone host for manual IME checks and platform conformance tests.
class TermworldExampleApp extends StatefulWidget {
  /// Creates the example application.
  const TermworldExampleApp({this.controller, super.key});

  /// Optional externally observed controller for integration tests.
  final TermworldExampleController? controller;

  @override
  State<TermworldExampleApp> createState() => _TermworldExampleAppState();
}

class _TermworldExampleAppState extends State<TermworldExampleApp> {
  late final TermworldExampleController _controller =
      widget.controller ?? TermworldExampleController();
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'termworld',
    home: Scaffold(
      appBar: AppBar(title: const Text('termworld conformance')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: TerminalView(
              key: const ValueKey<String>('terminal'),
              emulator: _controller.emulator,
              autofocus: true,
              semanticLabel: 'termworld terminal',
            ),
          ),
          Row(
            children: <Widget>[
              TextButton(
                key: const ValueKey<String>('paste-clipboard'),
                onPressed: _controller.pasteClipboard,
                child: const Text('Paste'),
              ),
              TextButton(
                key: const ValueKey<String>('focus-target'),
                onPressed: () {},
                child: const Text('Focus target'),
              ),
            ],
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, child) => SelectableText(
              _controller.output,
              key: const ValueKey<String>('pty-output'),
            ),
          ),
        ],
      ),
    ),
  );
}
