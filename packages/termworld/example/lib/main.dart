import 'package:flutter/material.dart';
import 'package:termworld/termworld.dart';

void main() => runApp(const TermworldExampleApp());

/// Standalone host for manual IME checks and platform conformance tests.
class TermworldExampleApp extends StatelessWidget {
  /// Creates the example application.
  const TermworldExampleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'termworld',
    home: _TerminalPage(),
  );
}

class _TerminalPage extends StatefulWidget {
  const _TerminalPage();

  @override
  State<_TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<_TerminalPage> {
  final StringBuffer _output = StringBuffer();
  late final TerminalEmulator _emulator = TerminalEmulator(
    onOutput: (value) => setState(() => _output.write(value)),
  )..write('\u001b[1;36mtermworld\u001b[0m\r\n한글 IME: ');

  @override
  void dispose() {
    _emulator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('termworld conformance')),
    body: Column(
      children: <Widget>[
        Expanded(
          child: TerminalView(
            key: const ValueKey<String>('terminal'),
            emulator: _emulator,
            autofocus: true,
            semanticLabel: 'termworld terminal',
          ),
        ),
        SelectableText(
          _output.toString(),
          key: const ValueKey<String>('pty-output'),
        ),
      ],
    ),
  );
}
