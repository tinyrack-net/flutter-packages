#include "dropwell_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/standard_method_codec.h>
#include <ole2.h>

#include <utility>
#include <variant>

#include "dropwell_testing.h"

namespace dropwell {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

}  // namespace

flutter::EncodableValue EncodeFiles(const std::vector<FileItem>& files) {
  EncodableList encoded;
  encoded.reserve(files.size());
  for (const FileItem& file : files) {
    EncodableMap map;
    map[EncodableValue("fileName")] = EncodableValue(file.file_name);
    map[EncodableValue("mimeType")] = file.mime_type.empty()
                                          ? EncodableValue()
                                          : EncodableValue(file.mime_type);
    if (!file.path.empty()) {
      map[EncodableValue("path")] = EncodableValue(file.path);
    } else {
      map[EncodableValue("bytes")] = EncodableValue(file.bytes);
    }
    encoded.push_back(EncodableValue(std::move(map)));
  }
  return EncodableValue(std::move(encoded));
}

void DropwellPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "dropwell",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<DropwellPlugin>(
      std::move(channel), registrar->GetView()->GetNativeWindow());
  RegisterTestingChannel(registrar, plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

DropwellPlugin::DropwellPlugin(
    std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel,
    HWND window)
    : channel_(std::move(channel)), window_(window) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });

  // The engine has already put this thread in an apartment, so this call only
  // balances the Uninitialize below. A failure means the thread cannot host a
  // drop target at all, and registering one anyway would corrupt it.
  if (FAILED(::OleInitialize(nullptr))) return;
  drop_target_ = new DropTarget(
      window_,
      DropDelegate{
          [this]() -> const std::vector<Rect>& { return regions_; },
          [this](const char* phase, double x, double y,
                 std::vector<FileItem> files) {
            ReportDrag(phase, x, y, std::move(files));
          },
      });
  if (FAILED(::RegisterDragDrop(window_, drop_target_))) {
    drop_target_->Release();
    drop_target_ = nullptr;
  }
}

DropwellPlugin::~DropwellPlugin() {
  if (drop_target_ != nullptr) {
    ::RevokeDragDrop(window_);
    drop_target_->Release();
    drop_target_ = nullptr;
  }
  ::OleUninitialize();
}

void DropwellPlugin::ReportDrag(const char* phase, double x, double y,
                                std::vector<FileItem> files) {
  EncodableMap arguments;
  arguments[EncodableValue("phase")] = EncodableValue(phase);
  arguments[EncodableValue("x")] = EncodableValue(x);
  arguments[EncodableValue("y")] = EncodableValue(y);
  arguments[EncodableValue("files")] = EncodeFiles(files);
  channel_->InvokeMethod(
      "drag", std::make_unique<EncodableValue>(std::move(arguments)));
}

void DropwellPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (method_call.method_name() == "readClipboardFiles") {
    result->Success(EncodeFiles(ReadClipboard()));
    return;
  }
  if (method_call.method_name() == "publishDropRegions") {
    const auto* flat = std::get_if<std::vector<double>>(method_call.arguments());
    if (flat == nullptr) {
      result->Error("bad-arguments", "publishDropRegions needs a double list");
      return;
    }
    auto parsed = ParseRegions(*flat);
    if (!parsed.has_value()) {
      result->Error("bad-arguments",
                    "publishDropRegions needs groups of four doubles");
      return;
    }
    regions_ = std::move(*parsed);
    result->Success();
    return;
  }
  result->NotImplemented();
}

}  // namespace dropwell
