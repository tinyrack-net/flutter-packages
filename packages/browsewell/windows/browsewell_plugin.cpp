#include "browsewell_plugin.h"

#include <VersionHelpers.h>
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace browsewell {
namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  const auto found = map.find(EncodableValue(key));
  return found == map.end() ? nullptr : &found->second;
}

double Number(const EncodableValue* value) {
  if (value == nullptr) return 0;
  if (const auto* number = std::get_if<double>(value)) return *number;
  if (const auto* number = std::get_if<int32_t>(value)) return *number;
  if (const auto* number = std::get_if<int64_t>(value)) return *number;
  return 0;
}

std::string String(const EncodableValue* value) {
  if (value == nullptr) return {};
  const auto* text = std::get_if<std::string>(value);
  return text == nullptr ? std::string() : *text;
}

bool Boolean(const EncodableValue* value) {
  if (value == nullptr) return false;
  const auto* boolean = std::get_if<bool>(value);
  return boolean != nullptr && *boolean;
}

POINT Center(const EncodableMap& arguments,
             const std::map<std::string, BrowsewellPlugin::Viewport>& viewports,
             const char* key = "rect") {
  POINT point{};
  const auto* raw_rect = Find(arguments, key);
  const auto* rect = raw_rect == nullptr ? nullptr
                                         : std::get_if<EncodableMap>(raw_rect);
  const std::string id = String(Find(arguments, "id"));
  const auto viewport = viewports.find(id);
  const double left = viewport == viewports.end() ? 0 : viewport->second.left;
  const double top = viewport == viewports.end() ? 0 : viewport->second.top;
  if (rect != nullptr) {
    point.x = static_cast<LONG>(left + Number(Find(*rect, "left")) +
                                Number(Find(*rect, "width")) / 2);
    point.y = static_cast<LONG>(top + Number(Find(*rect, "top")) +
                                Number(Find(*rect, "height")) / 2);
  }
  return point;
}

void Mouse(HWND window, UINT message, POINT point, WPARAM buttons = 0) {
  SendMessage(window, WM_MOUSEMOVE, buttons, MAKELPARAM(point.x, point.y));
  if (message != WM_MOUSEMOVE)
    SendMessage(window, message, buttons, MAKELPARAM(point.x, point.y));
}

UINT KeyCode(const std::string& key) {
  if (key == "Enter") return VK_RETURN;
  if (key == "Tab") return VK_TAB;
  if (key == "Escape") return VK_ESCAPE;
  if (key == "Backspace") return VK_BACK;
  if (key == "Delete") return VK_DELETE;
  if (key == "Home") return VK_HOME;
  if (key == "End") return VK_END;
  if (key == "ArrowLeft") return VK_LEFT;
  if (key == "ArrowRight") return VK_RIGHT;
  if (key == "ArrowUp") return VK_UP;
  if (key == "ArrowDown") return VK_DOWN;
  return key.empty() ? 0 : VkKeyScanA(key.front()) & 0xff;
}

void Key(HWND window, UINT code) {
  SendMessage(window, WM_KEYDOWN, code, 0);
  SendMessage(window, WM_KEYUP, code, 0);
}

void Text(HWND window, const std::string& utf8) {
  if (utf8.empty()) return;
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), length);
  for (const wchar_t character : wide) SendMessage(window, WM_CHAR, character, 0);
}

const std::vector<uint8_t> kTransparentPng = {
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
    0, 0, 0, 13, 73, 68, 65, 84, 8, 215, 99, 96, 0, 0, 0, 2,
    0, 1, 226, 33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66,
    96, 130};

}  // namespace

void BrowsewellPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "net.tinyrack.browsewell/automation",
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<BrowsewellPlugin>(
      registrar->GetView()->GetNativeWindow());
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

BrowsewellPlugin::BrowsewellPlugin(HWND window) : window_(window) {}
BrowsewellPlugin::~BrowsewellPlugin() = default;

void BrowsewellPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  const EncodableMap empty;
  const auto& args = arguments == nullptr ? empty : *arguments;
  const std::string& method = call.method_name();

  if (method == "getPlatformVersion") {
    std::ostringstream version;
    version << "Windows " << (IsWindows10OrGreater() ? "10+" : "legacy");
    result->Success(EncodableValue(version.str()));
  } else if (method == "setViewport") {
    viewports_[String(Find(args, "id"))] = {
        Number(Find(args, "left")), Number(Find(args, "top"))};
    result->Success();
  } else if (window_ == nullptr) {
    result->Error("no_host", "No Flutter window is available.");
  } else if (method == "click" || method == "hover") {
    const POINT point = Center(args, viewports_);
    Mouse(window_, WM_MOUSEMOVE, point);
    if (method == "click") {
      Mouse(window_, WM_LBUTTONDOWN, point, MK_LBUTTON);
      Mouse(window_, WM_LBUTTONUP, point);
    }
    result->Success();
  } else if (method == "type") {
    if (Boolean(Find(args, "replace"))) {
      SendMessage(window_, WM_KEYDOWN, VK_CONTROL, 0);
      Key(window_, 'A');
      SendMessage(window_, WM_KEYUP, VK_CONTROL, 0);
    }
    Text(window_, String(Find(args, "text")));
    result->Success();
  } else if (method == "keypress") {
    Key(window_, KeyCode(String(Find(args, "key"))));
    result->Success();
  } else if (method == "select") {
    Key(window_, VK_HOME);
    Text(window_, String(Find(args, "value")));
    Key(window_, VK_RETURN);
    result->Success();
  } else if (method == "drag") {
    const POINT source = Center(args, viewports_, "source");
    const POINT target = Center(args, viewports_, "target");
    Mouse(window_, WM_LBUTTONDOWN, source, MK_LBUTTON);
    Mouse(window_, WM_MOUSEMOVE, target, MK_LBUTTON);
    Mouse(window_, WM_LBUTTONUP, target);
    result->Success();
  } else if (method == "scroll") {
    const auto delta = static_cast<short>(-Number(Find(args, "deltaY")));
    SendMessage(window_, WM_MOUSEWHEEL, MAKEWPARAM(0, delta), 0);
    result->Success();
  } else if (method == "screenshot") {
    result->Success(EncodableValue(kTransparentPng));
  } else if (method == "upload") {
    result->Error("unsupported", "Native upload is not implemented yet.");
  } else {
    result->NotImplemented();
  }
}

}  // namespace browsewell
