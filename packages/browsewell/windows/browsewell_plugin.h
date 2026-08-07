#ifndef FLUTTER_PLUGIN_BROWSEWELL_PLUGIN_H_
#define FLUTTER_PLUGIN_BROWSEWELL_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <map>
#include <string>

namespace browsewell {

class BrowsewellPlugin : public flutter::Plugin {
 public:
  struct Viewport {
    double left;
    double top;
  };

  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit BrowsewellPlugin(HWND window = nullptr);

  virtual ~BrowsewellPlugin();

  // Disallow copy and assign.
  BrowsewellPlugin(const BrowsewellPlugin&) = delete;
  BrowsewellPlugin& operator=(const BrowsewellPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  HWND window_;
  std::map<std::string, Viewport> viewports_;
};

}  // namespace browsewell

#endif  // FLUTTER_PLUGIN_BROWSEWELL_PLUGIN_H_
