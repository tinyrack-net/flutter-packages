#include "browsewell_plugin.h"

#include <VersionHelpers.h>
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <chrono>
#include <memory>
#include <sstream>
#include <string>
#include <thread>
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
  if (const auto* number = std::get_if<int32_t>(value))
    return static_cast<double>(*number);
  if (const auto* number = std::get_if<int64_t>(value))
    return static_cast<double>(*number);
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
  const double scale = Number(Find(arguments, "devicePixelRatio"));
  const double ratio = scale > 0 ? scale : 1;
  if (rect != nullptr) {
    point.x = static_cast<LONG>((left + Number(Find(*rect, "left")) +
                                 Number(Find(*rect, "width")) / 2) * ratio);
    point.y = static_cast<LONG>((top + Number(Find(*rect, "top")) +
                                 Number(Find(*rect, "height")) / 2) * ratio);
  }
  return point;
}

void Mouse(HWND window, DWORD flags, POINT point, DWORD data = 0) {
  ClientToScreen(window, &point);
  const int left = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int top = GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
  INPUT input{};
  input.type = INPUT_MOUSE;
  input.mi.dx = static_cast<LONG>(
      (point.x - left) * 65535LL / (width > 1 ? width - 1 : 1));
  input.mi.dy = static_cast<LONG>(
      (point.y - top) * 65535LL / (height > 1 ? height - 1 : 1));
  input.mi.mouseData = data;
  input.mi.dwFlags = flags | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK;
  SendInput(1, &input, sizeof(INPUT));
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

void KeyEvent(UINT code, DWORD flags = 0) {
  INPUT input{};
  input.type = INPUT_KEYBOARD;
  input.ki.wVk = static_cast<WORD>(code);
  input.ki.dwFlags = flags;
  SendInput(1, &input, sizeof(INPUT));
}

void Key(HWND, UINT code) {
  KeyEvent(code);
  KeyEvent(code, KEYEVENTF_KEYUP);
}

void Text(HWND, const std::string& utf8) {
  if (utf8.empty()) return;
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), length);
  for (const wchar_t character : wide) {
    INPUT inputs[2]{};
    for (auto& input : inputs) {
      input.type = INPUT_KEYBOARD;
      input.ki.wScan = character;
      input.ki.dwFlags = KEYEVENTF_UNICODE;
    }
    inputs[1].ki.dwFlags |= KEYEVENTF_KEYUP;
    SendInput(2, inputs, sizeof(INPUT));
  }
}

BOOL CALLBACK FindFileDialog(HWND window, LPARAM data) {
  DWORD process = 0;
  GetWindowThreadProcessId(window, &process);
  wchar_t class_name[32] = {};
  GetClassName(window, class_name, 32);
  if (process == GetCurrentProcessId() && wcscmp(class_name, L"#32770") == 0 &&
      IsWindowVisible(window)) {
    *reinterpret_cast<HWND*>(data) = window;
    return FALSE;
  }
  return TRUE;
}

BOOL CALLBACK FindEdit(HWND window, LPARAM data) {
  wchar_t class_name[32] = {};
  GetClassName(window, class_name, 32);
  if (wcscmp(class_name, L"Edit") == 0) {
    *reinterpret_cast<HWND*>(data) = window;
    return FALSE;
  }
  return TRUE;
}

std::wstring Wide(const std::string& utf8) {
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), length);
  return wide;
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
    SetForegroundWindow(window_);
    SetFocus(window_);
    const POINT point = Center(args, viewports_);
    Mouse(window_, MOUSEEVENTF_MOVE, point);
    if (method == "click") {
      Mouse(window_, MOUSEEVENTF_LEFTDOWN, point);
      Mouse(window_, MOUSEEVENTF_LEFTUP, point);
    }
    result->Success();
  } else if (method == "type") {
    if (Boolean(Find(args, "replace"))) {
      KeyEvent(VK_CONTROL);
      Key(window_, 'A');
      KeyEvent(VK_CONTROL, KEYEVENTF_KEYUP);
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
    Mouse(window_, MOUSEEVENTF_MOVE, source);
    Mouse(window_, MOUSEEVENTF_LEFTDOWN, source);
    for (int step = 1; step <= 8; ++step) {
      POINT point{
          source.x + (target.x - source.x) * step / 8,
          source.y + (target.y - source.y) * step / 8,
      };
      Mouse(window_, MOUSEEVENTF_MOVE, point);
      Sleep(8);
    }
    Mouse(window_, MOUSEEVENTF_LEFTUP, target);
    result->Success();
  } else if (method == "scroll") {
    const auto delta = static_cast<short>(-Number(Find(args, "deltaY")));
    Mouse(window_, MOUSEEVENTF_WHEEL, POINT{}, static_cast<DWORD>(delta));
    result->Success();
  } else if (method == "screenshot") {
    result->Success(EncodableValue(kTransparentPng));
  } else if (method == "upload") {
    const auto* raw_paths = Find(args, "filePaths");
    const auto* paths = raw_paths == nullptr ? nullptr
                                              : std::get_if<EncodableList>(raw_paths);
    if (paths == nullptr || paths->empty()) {
      result->Error("denied", "Upload paths are missing.");
      return;
    }
    const std::string path = String(&paths->front());
    Key(window_, VK_RETURN);
    std::thread([path]() {
      for (int attempt = 0; attempt < 40; ++attempt) {
        HWND dialog = nullptr;
        EnumWindows(FindFileDialog, reinterpret_cast<LPARAM>(&dialog));
        if (dialog != nullptr) {
          HWND edit = nullptr;
          EnumChildWindows(dialog, FindEdit, reinterpret_cast<LPARAM>(&edit));
          if (edit != nullptr) {
            const std::wstring wide = Wide(path);
            SetWindowText(edit, wide.c_str());
            SendMessage(dialog, WM_COMMAND, IDOK, 0);
            return;
          }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
      }
    }).detach();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace browsewell
