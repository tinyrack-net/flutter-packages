import 'package:web/web.dart' as web;

/// Opens a link without retaining an opener reference, matching xterm.js.
void openWebLink(Object? event, String uri) {
  final target = web.window.open('', '_blank');
  if (target == null) return;
  target
    ..opener = null
    ..location.href = uri;
}
