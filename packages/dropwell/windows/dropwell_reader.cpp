#include "dropwell_reader.h"

#include <shlwapi.h>
#include <wincodec.h>
#include <wrl/client.h>

#include "dropwell_data.h"

namespace dropwell {

namespace {

using Microsoft::WRL::ComPtr;

/// The clipboard format modern applications use for a lossless pasted image.
///
/// Browsers and design tools register "PNG" and put an already-encoded image
/// there. Preferring it over `CF_DIB` avoids a decode/encode round trip and
/// keeps the alpha channel that a v3 DIB cannot express.
UINT PngClipboardFormat() {
  static const UINT format = ::RegisterClipboardFormatW(L"PNG");
  return format;
}

FORMATETC MakeFormat(UINT clipboard_format) {
  return FORMATETC{static_cast<CLIPFORMAT>(clipboard_format), nullptr,
                   DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
}

/// Copies an `HGLOBAL` medium into a byte vector.
std::vector<uint8_t> ReadGlobal(const STGMEDIUM& medium) {
  const SIZE_T size = ::GlobalSize(medium.hGlobal);
  const void* locked = ::GlobalLock(medium.hGlobal);
  if (locked == nullptr) return {};
  std::vector<uint8_t> bytes(static_cast<const uint8_t*>(locked),
                             static_cast<const uint8_t*>(locked) + size);
  ::GlobalUnlock(medium.hGlobal);
  return bytes;
}

bool TryRead(IDataObject* data, UINT clipboard_format,
             std::vector<uint8_t>* out) {
  FORMATETC format = MakeFormat(clipboard_format);
  STGMEDIUM medium{};
  if (FAILED(data->GetData(&format, &medium))) return false;
  *out = ReadGlobal(medium);
  ::ReleaseStgMedium(&medium);
  return !out->empty();
}

bool HasFormat(IDataObject* data, UINT clipboard_format) {
  FORMATETC format = MakeFormat(clipboard_format);
  return data->QueryGetData(&format) == S_OK;
}

FileItem ImageItem(std::vector<uint8_t> bytes) {
  FileItem item;
  item.file_name = "pasted-image.png";
  item.mime_type = "image/png";
  item.bytes = std::move(bytes);
  return item;
}

}  // namespace

std::vector<uint8_t> PngFromDib(const uint8_t* data, size_t size) {
  const auto bmp = BmpFromDib(data, size);
  if (!bmp.has_value()) return {};

  ComPtr<IWICImagingFactory> factory;
  if (FAILED(::CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&factory)))) {
    return {};
  }
  ComPtr<IStream> source;
  source.Attach(::SHCreateMemStream(bmp->data(),
                                    static_cast<UINT>(bmp->size())));
  if (source == nullptr) return {};

  ComPtr<IWICBitmapDecoder> decoder;
  if (FAILED(factory->CreateDecoderFromStream(
          source.Get(), nullptr, WICDecodeMetadataCacheOnLoad, &decoder))) {
    return {};
  }
  ComPtr<IWICBitmapFrameDecode> frame;
  if (FAILED(decoder->GetFrame(0, &frame))) return {};

  ComPtr<IStream> target;
  target.Attach(::SHCreateMemStream(nullptr, 0));
  if (target == nullptr) return {};
  ComPtr<IWICBitmapEncoder> encoder;
  if (FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder)) ||
      FAILED(encoder->Initialize(target.Get(), WICBitmapEncoderNoCache))) {
    return {};
  }
  ComPtr<IWICBitmapFrameEncode> encoded;
  ComPtr<IPropertyBag2> options;
  if (FAILED(encoder->CreateNewFrame(&encoded, &options)) ||
      FAILED(encoded->Initialize(options.Get())) ||
      FAILED(encoded->WriteSource(frame.Get(), nullptr)) ||
      FAILED(encoded->Commit()) || FAILED(encoder->Commit())) {
    return {};
  }

  STATSTG stat{};
  if (FAILED(target->Stat(&stat, STATFLAG_NONAME))) return {};
  const ULONG length = static_cast<ULONG>(stat.cbSize.QuadPart);
  std::vector<uint8_t> png(length);
  LARGE_INTEGER origin{};
  if (FAILED(target->Seek(origin, STREAM_SEEK_SET, nullptr))) return {};
  ULONG read = 0;
  if (FAILED(target->Read(png.data(), length, &read)) || read != length) {
    return {};
  }
  return png;
}

bool HasSupportedFormat(IDataObject* data) {
  if (data == nullptr) return false;
  return HasFormat(data, CF_HDROP) || HasFormat(data, PngClipboardFormat()) ||
         HasFormat(data, CF_DIBV5) || HasFormat(data, CF_DIB);
}

std::vector<FileItem> ReadDataObject(IDataObject* data) {
  if (data == nullptr) return {};

  std::vector<uint8_t> buffer;
  if (TryRead(data, CF_HDROP, &buffer)) {
    const auto paths = ParseHdrop(buffer.data(), buffer.size());
    if (!paths.has_value()) return {};
    std::vector<FileItem> items;
    items.reserve(paths->size());
    for (const std::string& path : *paths) {
      FileItem item;
      item.file_name = FileNameOf(path);
      item.mime_type = MimeFromFileName(item.file_name);
      item.path = path;
      items.push_back(std::move(item));
    }
    return items;
  }
  if (TryRead(data, PngClipboardFormat(), &buffer)) {
    return {ImageItem(std::move(buffer))};
  }
  for (const UINT format : {CF_DIBV5, CF_DIB}) {
    if (!TryRead(data, format, &buffer)) continue;
    std::vector<uint8_t> png = PngFromDib(buffer.data(), buffer.size());
    if (png.empty()) continue;
    return {ImageItem(std::move(png))};
  }
  return {};
}

std::vector<FileItem> ReadClipboard() {
  // OleGetClipboard hands back the clipboard as a data object, so the drop
  // path and the paste path share one reader and cannot drift apart.
  Microsoft::WRL::ComPtr<IDataObject> data;
  if (FAILED(::OleGetClipboard(&data))) return {};
  return ReadDataObject(data.Get());
}

}  // namespace dropwell
