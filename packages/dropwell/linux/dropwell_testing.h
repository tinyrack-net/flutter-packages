#ifndef FLUTTER_PLUGIN_DROPWELL_TESTING_H_
#define FLUTTER_PLUGIN_DROPWELL_TESTING_H_

#include <flutter_linux/flutter_linux.h>

#include "include/dropwell/dropwell_plugin.h"

/// Registers the Debug-only channel the conformance suite drives.
///
/// In a Release build this compiles to an empty function and the channel name
/// never reaches the binary, which `tool/verify_release_hooks.dart` checks by
/// searching the built artifact rather than trusting this guard.
void dropwell_register_testing_channel(FlPluginRegistrar* registrar,
                                       DropwellPlugin* plugin);

#endif  // FLUTTER_PLUGIN_DROPWELL_TESTING_H_
