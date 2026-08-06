#ifndef FLUTTER_PLUGIN_DROPWELL_PLUGIN_H_
#define FLUTTER_PLUGIN_DROPWELL_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <vector>

#include "dropwell_data.h"
#include "dropwell_drop_target.h"
#include "dropwell_reader.h"

namespace dropwell {

/// Windows implementation of the dropwell platform boundary.
class DropwellPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  DropwellPlugin(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel,
      HWND window);
  ~DropwellPlugin() override;

  DropwellPlugin(const DropwellPlugin&) = delete;
  DropwellPlugin& operator=(const DropwellPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  /// Sends a drag phase to Dart.
  void ReportDrag(const char* phase, double x, double y,
                  std::vector<FileItem> files);

  /// Regions Dart published as accepting a drop.
  const std::vector<Rect>& regions() const { return regions_; }

  /// The window the drop target is registered on.
  HWND window() const { return window_; }

  /// The live drop target, which the Debug-only testing channel drives.
  DropTarget* drop_target() const { return drop_target_; }

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_;
  DropTarget* drop_target_ = nullptr;
  std::vector<Rect> regions_;
};

/// Encodes files for the method channel.
flutter::EncodableValue EncodeFiles(const std::vector<FileItem>& files);

}  // namespace dropwell

#endif  // FLUTTER_PLUGIN_DROPWELL_PLUGIN_H_
