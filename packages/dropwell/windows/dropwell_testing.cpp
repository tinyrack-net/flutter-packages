#include "dropwell_testing.h"

#include <windows.h>

#include "dropwell_plugin.h"

#ifdef NDEBUG

namespace dropwell {

void RegisterTestingChannel(flutter::PluginRegistrarWindows* /*registrar*/,
                            DropwellPlugin* /*plugin*/) {}

}  // namespace dropwell

#else

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <ole2.h>
#include <shlobj.h>

#include <cstdio>
#include <fstream>
#include <memory>
#include <string>
#include <variant>
#include <vector>

#include "dropwell_data.h"

namespace dropwell {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  const auto entry = map.find(EncodableValue(key));
  return entry == map.end() ? nullptr : &entry->second;
}

template <typename T>
T ValueOr(const EncodableMap& map, const char* key, T fallback) {
  const EncodableValue* value = Find(map, key);
  if (value == nullptr) return fallback;
  const T* typed = std::get_if<T>(value);
  return typed == nullptr ? fallback : *typed;
}

/// Writes a payload into the temporary directory under its own name.
///
/// The clipboard and a drag payload both hand over *files*, so a suite that
/// only ever passed bytes would never exercise the path that real users take.
std::wstring MaterializeFile(const std::string& file_name,
                             const std::vector<uint8_t>& bytes) {
  wchar_t directory[MAX_PATH] = {};
  if (::GetTempPathW(MAX_PATH, directory) == 0) return {};
  std::wstring path = std::wstring(directory) + L"dropwell\\";
  ::CreateDirectoryW(path.c_str(), nullptr);
  path += WideFromUtf8(file_name);
  std::ofstream out(path, std::ios::binary | std::ios::trunc);
  if (!out) return {};
  if (!bytes.empty()) {
    out.write(reinterpret_cast<const char*>(bytes.data()),
              static_cast<std::streamsize>(bytes.size()));
  }
  return path;
}

std::vector<std::wstring> MaterializeAll(const EncodableList& files) {
  std::vector<std::wstring> paths;
  for (const EncodableValue& entry : files) {
    const auto* map = std::get_if<EncodableMap>(&entry);
    if (map == nullptr) continue;
    const std::string file_name = ValueOr<std::string>(*map, "fileName", "");
    if (file_name.empty()) continue;
    const std::string existing = ValueOr<std::string>(*map, "path", "");
    if (!existing.empty()) {
      paths.push_back(WideFromUtf8(existing));
      continue;
    }
    const auto* bytes = Find(*map, "bytes");
    const std::vector<uint8_t> payload =
        bytes == nullptr ? std::vector<uint8_t>{}
                         : std::get<std::vector<uint8_t>>(*bytes);
    std::wstring path = MaterializeFile(file_name, payload);
    if (!path.empty()) paths.push_back(std::move(path));
  }
  return paths;
}

/// Builds a `CF_HDROP` payload naming every path.
std::vector<uint8_t> BuildHdrop(const std::vector<std::wstring>& paths) {
  std::vector<uint8_t> buffer(sizeof(DROPFILES), 0);
  auto* header = reinterpret_cast<DROPFILES*>(buffer.data());
  header->pFiles = sizeof(DROPFILES);
  header->fWide = TRUE;
  for (const std::wstring& path : paths) {
    const auto* bytes = reinterpret_cast<const uint8_t*>(path.c_str());
    buffer.insert(buffer.end(), bytes,
                  bytes + (path.size() + 1) * sizeof(wchar_t));
  }
  buffer.push_back(0);
  buffer.push_back(0);
  return buffer;
}

HGLOBAL GlobalFrom(const std::vector<uint8_t>& bytes) {
  HGLOBAL handle = ::GlobalAlloc(GMEM_MOVEABLE, bytes.size());
  if (handle == nullptr) return nullptr;
  void* locked = ::GlobalLock(handle);
  if (locked == nullptr) {
    ::GlobalFree(handle);
    return nullptr;
  }
  std::memcpy(locked, bytes.data(), bytes.size());
  ::GlobalUnlock(handle);
  return handle;
}

/// A data object carrying one clipboard format.
///
/// The suite hands this to the plugin's own `IDropTarget`, so a synthesized
/// drop travels the same marshalling and parsing code an OLE drag would. Only
/// the two methods the reader calls are implemented; anything else is a
/// mistake the suite should hear about rather than silently tolerate.
class TestDataObject : public IDataObject {
 public:
  TestDataObject(UINT clipboard_format, std::vector<uint8_t> bytes)
      : format_(static_cast<CLIPFORMAT>(clipboard_format)),
        bytes_(std::move(bytes)) {}

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** object) override {
    if (object == nullptr) return E_POINTER;
    if (riid == IID_IUnknown || riid == IID_IDataObject) {
      *object = static_cast<IDataObject*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }

  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG remaining = --references_;
    if (remaining == 0) delete this;
    return remaining;
  }

  HRESULT STDMETHODCALLTYPE GetData(FORMATETC* requested,
                                    STGMEDIUM* medium) override {
    if (QueryGetData(requested) != S_OK) return DV_E_FORMATETC;
    medium->tymed = TYMED_HGLOBAL;
    medium->hGlobal = GlobalFrom(bytes_);
    medium->pUnkForRelease = nullptr;
    return medium->hGlobal == nullptr ? E_OUTOFMEMORY : S_OK;
  }

  HRESULT STDMETHODCALLTYPE QueryGetData(FORMATETC* requested) override {
    if (requested == nullptr) return E_INVALIDARG;
    const bool matches = requested->cfFormat == format_ &&
                         (requested->tymed & TYMED_HGLOBAL) != 0;
    return matches ? S_OK : DV_E_FORMATETC;
  }

  HRESULT STDMETHODCALLTYPE GetDataHere(FORMATETC*, STGMEDIUM*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE GetCanonicalFormatEtc(FORMATETC*,
                                                  FORMATETC*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE SetData(FORMATETC*, STGMEDIUM*, BOOL) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE EnumFormatEtc(DWORD, IEnumFORMATETC**) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE DAdvise(FORMATETC*, DWORD, IAdviseSink*,
                                    DWORD*) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }
  HRESULT STDMETHODCALLTYPE DUnadvise(DWORD) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }
  HRESULT STDMETHODCALLTYPE EnumDAdvise(IEnumSTATDATA**) override {
    return OLE_E_ADVISENOTSUPPORTED;
  }

 private:
  CLIPFORMAT format_;
  std::vector<uint8_t> bytes_;
  ULONG references_ = 1;
};

bool WriteClipboard(UINT clipboard_format, const std::vector<uint8_t>& bytes) {
  if (!::OpenClipboard(nullptr)) return false;
  ::EmptyClipboard();
  const bool written =
      bytes.empty() ||
      ::SetClipboardData(clipboard_format, GlobalFrom(bytes)) != nullptr;
  ::CloseClipboard();
  return written;
}

POINTL ScreenPointOf(HWND window, double x, double y) {
  POINT point{static_cast<LONG>(x), static_cast<LONG>(y)};
  ::ClientToScreen(window, &point);
  return POINTL{point.x, point.y};
}

void HandleCall(DropwellPlugin* plugin,
                const flutter::MethodCall<EncodableValue>& call,
                std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "clearSystemClipboard") {
    if (!::OpenClipboard(nullptr)) {
      result->Error("clipboard", "could not open the clipboard");
      return;
    }
    ::EmptyClipboard();
    ::CloseClipboard();
    result->Success();
    return;
  }

  if (method == "setSystemClipboard") {
    const auto* arguments = std::get_if<EncodableMap>(call.arguments());
    if (arguments == nullptr) {
      result->Error("bad-arguments", "setSystemClipboard needs a map");
      return;
    }
    const auto* files = Find(*arguments, "files");
    const EncodableList list =
        files == nullptr ? EncodableList{} : std::get<EncodableList>(*files);
    if (ValueOr<bool>(*arguments, "asBitmap", false)) {
      // A pasted screenshot arrives as an image with no name, so the suite can
      // ask for that shape explicitly instead of only ever seeing file drops.
      const auto* entry = std::get_if<EncodableMap>(&list.front());
      const auto* bytes = entry == nullptr ? nullptr : Find(*entry, "bytes");
      if (bytes == nullptr) {
        result->Error("bad-arguments", "a bitmap needs bytes");
        return;
      }
      const UINT png = ::RegisterClipboardFormatW(L"PNG");
      result->Success(EncodableValue(
          WriteClipboard(png, std::get<std::vector<uint8_t>>(*bytes))));
      return;
    }
    result->Success(
        EncodableValue(WriteClipboard(CF_HDROP, BuildHdrop(MaterializeAll(list)))));
    return;
  }

  if (method == "synthesizeDrag") {
    DropTarget* target = plugin->drop_target();
    const auto* arguments = std::get_if<EncodableMap>(call.arguments());
    if (target == nullptr || arguments == nullptr) {
      result->Error("bad-arguments", "synthesizeDrag needs a live drop target");
      return;
    }
    const std::string phase = ValueOr<std::string>(*arguments, "phase", "");
    const double x = ValueOr<double>(*arguments, "x", 0);
    const double y = ValueOr<double>(*arguments, "y", 0);
    const auto* files = Find(*arguments, "files");
    const EncodableList list =
        files == nullptr ? EncodableList{} : std::get<EncodableList>(*files);

    const POINTL point = ScreenPointOf(plugin->window(), x, y);
    DWORD effect = DROPEFFECT_COPY;
    if (phase == "leave") {
      target->DragLeave();
      result->Success();
      return;
    }
    auto* data = new TestDataObject(CF_HDROP, BuildHdrop(MaterializeAll(list)));
    if (phase == "enter") {
      target->DragEnter(data, MK_LBUTTON, point, &effect);
    } else if (phase == "over") {
      target->DragOver(MK_LBUTTON, point, &effect);
    } else if (phase == "perform") {
      target->DragEnter(data, MK_LBUTTON, point, &effect);
      target->Drop(data, MK_LBUTTON, point, &effect);
    } else {
      data->Release();
      result->Error("bad-arguments", "unknown drag phase " + phase);
      return;
    }
    data->Release();
    result->Success();
    return;
  }

  if (method == "readFile") {
    const auto* path = std::get_if<std::string>(call.arguments());
    if (path == nullptr) {
      result->Error("bad-arguments", "readFile needs a path");
      return;
    }
    std::ifstream in(WideFromUtf8(*path), std::ios::binary);
    if (!in) {
      result->Error("io", "could not open " + *path);
      return;
    }
    const std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(in)),
                                     std::istreambuf_iterator<char>());
    result->Success(EncodableValue(bytes));
    return;
  }

  result->NotImplemented();
}

}  // namespace

void RegisterTestingChannel(flutter::PluginRegistrarWindows* registrar,
                            DropwellPlugin* plugin) {
  auto channel = std::make_shared<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "dropwell/testing",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [plugin, channel](const auto& call, auto result) {
        HandleCall(plugin, call, std::move(result));
      });
}

}  // namespace dropwell

#endif  // NDEBUG
