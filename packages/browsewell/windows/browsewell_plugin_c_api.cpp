#include "include/browsewell/browsewell_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "browsewell_plugin.h"

void BrowsewellPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  browsewell::BrowsewellPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
