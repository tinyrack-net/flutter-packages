#ifndef FLUTTER_PLUGIN_DROPWELL_READER_H_
#define FLUTTER_PLUGIN_DROPWELL_READER_H_

#include <objidl.h>
#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

namespace dropwell {

/// One file carried by a drop payload or the clipboard.
///
/// Exactly one of `path` and `bytes` is populated, matching the Dart type.
struct FileItem {
  std::string file_name;
  std::string mime_type;
  std::string path;
  std::vector<uint8_t> bytes;
};

/// Reads every file this package can represent out of a data object.
///
/// A drop payload and the clipboard are both `IDataObject`s, so one reader
/// serves both and neither can quietly support a format the other does not.
/// Formats are tried in the order a user would expect: real files first, then
/// a ready-made PNG, then a raw bitmap that has to be re-encoded.
std::vector<FileItem> ReadDataObject(IDataObject* data);

/// Reads the clipboard as a data object.
std::vector<FileItem> ReadClipboard();

/// Whether a data object carries anything this package can accept.
bool HasSupportedFormat(IDataObject* data);

/// Re-encodes a device-independent bitmap as PNG.
///
/// Returns an empty vector when the payload cannot be decoded, which is the
/// honest answer for a clipboard holding a bitmap this machine's codecs cannot
/// read.
std::vector<uint8_t> PngFromDib(const uint8_t* data, size_t size);

}  // namespace dropwell

#endif  // FLUTTER_PLUGIN_DROPWELL_READER_H_
