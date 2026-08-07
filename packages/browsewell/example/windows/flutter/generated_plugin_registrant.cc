//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <browsewell/browsewell_plugin_c_api.h>
#include <webview_all_windows/webview_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  BrowsewellPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("BrowsewellPluginCApi"));
  WebviewWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WebviewWindowsPlugin"));
}
