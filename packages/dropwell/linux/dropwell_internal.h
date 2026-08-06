#ifndef FLUTTER_PLUGIN_DROPWELL_INTERNAL_H_
#define FLUTTER_PLUGIN_DROPWELL_INTERNAL_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <string>

#include "include/dropwell/dropwell_plugin.h"

// Entry points shared by the GTK signal handlers and the Debug-only testing
// channel.
//
// Both go through the same functions with the same raw payloads, so a
// synthesized drop exercises the real parsing and the real channel message;
// only GTK's own selection delivery sits outside the conformance suite.

/// Reports a positioned drag phase to Dart.
void dropwell_plugin_report_drag(DropwellPlugin* plugin, const char* phase,
                                 double x, double y);

/// Reports a completed drop carrying a `text/uri-list` payload.
void dropwell_plugin_deliver_uri_list(DropwellPlugin* plugin, double x,
                                      double y, const std::string& uri_list);

/// Whether a published drop region contains the physical-pixel point.
gboolean dropwell_plugin_accepts(DropwellPlugin* plugin, double x, double y);

/// The Flutter view this plugin is attached to.
GtkWidget* dropwell_plugin_view(DropwellPlugin* plugin);

#endif  // FLUTTER_PLUGIN_DROPWELL_INTERNAL_H_
