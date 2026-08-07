//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <browsewell/browsewell_plugin.h>
#include <webview_all_linux/webview_all_linux_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) browsewell_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "BrowsewellPlugin");
  browsewell_plugin_register_with_registrar(browsewell_registrar);
  g_autoptr(FlPluginRegistrar) webview_all_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WebviewAllLinuxPlugin");
  webview_all_linux_plugin_register_with_registrar(webview_all_linux_registrar);
}
