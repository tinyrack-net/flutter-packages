//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <dropwell/dropwell_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) dropwell_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DropwellPlugin");
  dropwell_plugin_register_with_registrar(dropwell_registrar);
}
