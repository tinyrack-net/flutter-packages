import 'package:dropwell/dropwell.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const DropwellExampleApp());

/// Hosts a single drop region so the conformance suite has a real app to
/// drive, and so a person can sanity-check a platform by hand.
class DropwellExampleApp extends StatelessWidget {
  /// Creates the example app.
  const DropwellExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: 'dropwell', home: _HomePage());
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final List<DropwellFile> _files = <DropwellFile>[];
  bool _hovering = false;

  Future<void> _paste() async {
    final files = await DropwellPlatform.instance.readClipboardFiles();
    if (!mounted) return;
    setState(() => _files.addAll(files));
  }

  @override
  Widget build(BuildContext context) {
    final platform = DropwellPlatform.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('dropwell'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('paste'),
            onPressed: platform.supportsClipboardFiles ? _paste : null,
            icon: const Icon(Icons.paste),
          ),
        ],
      ),
      body: DropwellRegion(
        key: const ValueKey<String>('region'),
        onHoverChanged: (hovering) => setState(() => _hovering = hovering),
        onDrop: (files) async {
          if (!mounted) return;
          setState(() => _files.addAll(files));
        },
        child: ColoredBox(
          color: _hovering ? const Color(0x1A2196F3) : const Color(0x00000000),
          child: Column(
            children: <Widget>[
              Text(
                'supportsDrop: ${platform.supportsDrop} '
                'supportsClipboardFiles: ${platform.supportsClipboardFiles}',
                key: const ValueKey<String>('capabilities'),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(_files[index].fileName),
                    subtitle: Text(_files[index].mimeType ?? 'unknown'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
