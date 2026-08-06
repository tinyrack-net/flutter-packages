#include "include/dropwell/dropwell_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "dropwell_plugin.h"

void DropwellPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  dropwell::DropwellPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
