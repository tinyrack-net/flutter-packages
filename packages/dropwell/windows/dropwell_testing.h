#ifndef FLUTTER_PLUGIN_DROPWELL_TESTING_H_
#define FLUTTER_PLUGIN_DROPWELL_TESTING_H_

#include <flutter/plugin_registrar_windows.h>

namespace dropwell {

class DropwellPlugin;

/// Registers the Debug-only channel the conformance suite drives.
///
/// In a Release build this compiles to an empty function and the channel name
/// never reaches the binary, which `tool/verify_release_hooks.dart` checks by
/// searching the built artifact rather than trusting this guard.
void RegisterTestingChannel(flutter::PluginRegistrarWindows* registrar,
                            DropwellPlugin* plugin);

}  // namespace dropwell

#endif  // FLUTTER_PLUGIN_DROPWELL_TESTING_H_
