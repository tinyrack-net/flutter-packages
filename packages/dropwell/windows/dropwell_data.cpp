#include "dropwell_data.h"

#include <windows.h>

#include <algorithm>
#include <cstring>

namespace dropwell {

namespace {

// Layout of the DROPFILES header that precedes a CF_HDROP payload:
// DWORD pFiles; POINT pt; BOOL fNC; BOOL fWide.
constexpr size_t kDropFilesSize = 20;
constexpr size_t kDropFilesOffsetField = 0;
constexpr size_t kDropFilesWideField = 16;

constexpr size_t kBitmapFileHeaderSize = 14;
constexpr uint32_t kBitmapCoreHeaderSize = 12;
constexpr uint32_t kBitmapInfoHeaderSize = 40;
constexpr uint32_t kCompressionBitfields = 3;

uint16_t ReadU16(const uint8_t* data, size_t offset) {
  uint16_t value = 0;
  std::memcpy(&value, data + offset, sizeof(value));
  return value;
}

uint32_t ReadU32(const uint8_t* data, size_t offset) {
  uint32_t value = 0;
  std::memcpy(&value, data + offset, sizeof(value));
  return value;
}

void WriteU16(std::vector<uint8_t>& out, uint16_t value) {
  out.push_back(static_cast<uint8_t>(value & 0xFF));
  out.push_back(static_cast<uint8_t>((value >> 8) & 0xFF));
}

void WriteU32(std::vector<uint8_t>& out, uint32_t value) {
  for (int shift = 0; shift < 32; shift += 8) {
    out.push_back(static_cast<uint8_t>((value >> shift) & 0xFF));
  }
}

std::string LowerExtension(const std::string& file_name) {
  const size_t dot = file_name.find_last_of('.');
  if (dot == std::string::npos || dot + 1 >= file_name.size()) return {};
  std::string extension = file_name.substr(dot + 1);
  std::transform(extension.begin(), extension.end(), extension.begin(),
                 [](unsigned char c) { return static_cast<char>(::tolower(c)); });
  return extension;
}

}  // namespace

bool Rect::Contains(double x, double y) const {
  return x >= left && x < right && y >= top && y < bottom;
}

std::string Utf8FromWide(const std::wstring& value) {
  if (value.empty()) return {};
  const int size =
      ::WideCharToMultiByte(CP_UTF8, 0, value.data(),
                            static_cast<int>(value.size()), nullptr, 0, nullptr,
                            nullptr);
  if (size <= 0) return {};
  std::string result(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, value.data(),
                        static_cast<int>(value.size()), result.data(), size,
                        nullptr, nullptr);
  return result;
}

std::wstring WideFromUtf8(const std::string& value) {
  if (value.empty()) return {};
  const int size = ::MultiByteToWideChar(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
  if (size <= 0) return {};
  std::wstring result(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, value.data(),
                        static_cast<int>(value.size()), result.data(), size);
  return result;
}

std::string FileNameOf(const std::string& path) {
  const size_t separator = path.find_last_of("\\/");
  return separator == std::string::npos ? path : path.substr(separator + 1);
}

std::optional<std::vector<Rect>> ParseRegions(const std::vector<double>& flat) {
  if (flat.size() % 4 != 0) return std::nullopt;
  std::vector<Rect> regions;
  regions.reserve(flat.size() / 4);
  for (size_t index = 0; index + 3 < flat.size(); index += 4) {
    regions.push_back(
        Rect{flat[index], flat[index + 1], flat[index + 2], flat[index + 3]});
  }
  return regions;
}

bool AnyContains(const std::vector<Rect>& regions, double x, double y) {
  return std::any_of(regions.begin(), regions.end(),
                     [x, y](const Rect& rect) { return rect.Contains(x, y); });
}

std::optional<std::vector<std::string>> ParseHdrop(const uint8_t* data,
                                                   size_t size) {
  if (data == nullptr || size < kDropFilesSize) return std::nullopt;
  const uint32_t offset = ReadU32(data, kDropFilesOffsetField);
  const bool wide = ReadU32(data, kDropFilesWideField) != 0;
  if (offset < kDropFilesSize || offset > size) return std::nullopt;

  std::vector<std::string> paths;
  size_t cursor = offset;
  if (wide) {
    while (cursor + sizeof(wchar_t) <= size) {
      const wchar_t* entry = reinterpret_cast<const wchar_t*>(data + cursor);
      const size_t available = (size - cursor) / sizeof(wchar_t);
      size_t length = 0;
      while (length < available && entry[length] != L'\0') length++;
      if (length == 0) break;
      paths.push_back(Utf8FromWide(std::wstring(entry, length)));
      cursor += (length + 1) * sizeof(wchar_t);
    }
    return paths;
  }
  while (cursor < size) {
    const char* entry = reinterpret_cast<const char*>(data + cursor);
    const size_t available = size - cursor;
    size_t length = 0;
    while (length < available && entry[length] != '\0') length++;
    if (length == 0) break;
    // A narrow CF_HDROP is ANSI, so round-trip it through UTF-16 rather than
    // assuming the bytes are already UTF-8.
    const int wide_size = ::MultiByteToWideChar(CP_ACP, 0, entry,
                                                static_cast<int>(length),
                                                nullptr, 0);
    // windows.h defines `max` as a macro, so this stays a plain comparison.
    const size_t converted_size =
        wide_size > 0 ? static_cast<size_t>(wide_size) : 0;
    std::wstring converted(converted_size, L'\0');
    if (wide_size > 0) {
      ::MultiByteToWideChar(CP_ACP, 0, entry, static_cast<int>(length),
                            converted.data(), wide_size);
    }
    paths.push_back(Utf8FromWide(converted));
    cursor += length + 1;
  }
  return paths;
}

std::optional<std::vector<uint8_t>> BmpFromDib(const uint8_t* data,
                                               size_t size) {
  if (data == nullptr || size < sizeof(uint32_t)) return std::nullopt;
  const uint32_t header_size = ReadU32(data, 0);
  if (header_size < kBitmapCoreHeaderSize || header_size > size) {
    return std::nullopt;
  }

  size_t palette_bytes = 0;
  size_t mask_bytes = 0;
  if (header_size == kBitmapCoreHeaderSize) {
    if (size < 10) return std::nullopt;
    const uint16_t bit_count = ReadU16(data, 8);
    if (bit_count <= 8) palette_bytes = (size_t{1} << bit_count) * 3;
  } else {
    if (size < 36) return std::nullopt;
    const uint16_t bit_count = ReadU16(data, 14);
    const uint32_t compression = ReadU32(data, 16);
    const uint32_t colors_used = ReadU32(data, 32);
    const size_t entries = colors_used != 0
                               ? colors_used
                               : (bit_count <= 8 ? size_t{1} << bit_count : 0);
    palette_bytes = entries * 4;
    // A v3 header stores its channel masks after the header; v4 and v5 headers
    // already contain them, so adding them again would shift every pixel.
    if (compression == kCompressionBitfields &&
        header_size == kBitmapInfoHeaderSize) {
      mask_bytes = 12;
    }
  }

  const size_t pixel_offset =
      kBitmapFileHeaderSize + header_size + mask_bytes + palette_bytes;
  if (pixel_offset < kBitmapFileHeaderSize + header_size) return std::nullopt;

  std::vector<uint8_t> bmp;
  bmp.reserve(kBitmapFileHeaderSize + size);
  bmp.push_back('B');
  bmp.push_back('M');
  WriteU32(bmp, static_cast<uint32_t>(kBitmapFileHeaderSize + size));
  WriteU16(bmp, 0);
  WriteU16(bmp, 0);
  WriteU32(bmp, static_cast<uint32_t>(pixel_offset));
  bmp.insert(bmp.end(), data, data + size);
  return bmp;
}

std::string MimeFromFileName(const std::string& file_name) {
  const std::string extension = LowerExtension(file_name);
  if (extension == "png") return "image/png";
  if (extension == "jpg" || extension == "jpeg") return "image/jpeg";
  if (extension == "webp") return "image/webp";
  if (extension == "gif") return "image/gif";
  if (extension == "bmp") return "image/bmp";
  if (extension == "pdf") return "application/pdf";
  if (extension == "json") return "application/json";
  if (extension == "csv") return "text/csv";
  if (extension == "txt" || extension == "md" || extension == "log") {
    return "text/plain";
  }
  return {};
}

}  // namespace dropwell
