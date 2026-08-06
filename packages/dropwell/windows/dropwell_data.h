#ifndef FLUTTER_PLUGIN_DROPWELL_DATA_H_
#define FLUTTER_PLUGIN_DROPWELL_DATA_H_

// Pure data handling for the Windows implementation.
//
// Nothing here touches Flutter, a window, or the clipboard, so all of it is
// reachable from the googletest binary. These are the routines that actually
// break in the field: a CF_HDROP walked with the wrong stride silently drops
// every file after one whose name contains a surrogate pair, and a DIB wrapped
// with a miscomputed offset decodes to garbage. Keeping them here means a
// failure shows up as a unit test rather than as a user losing an attachment.

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace dropwell {

/// A drop region in physical pixels, relative to the view origin.
struct Rect {
  double left = 0;
  double top = 0;
  double right = 0;
  double bottom = 0;

  /// Whether this rectangle contains the point, top-left inclusive.
  bool Contains(double x, double y) const;
};

/// Converts UTF-16 to UTF-8.
std::string Utf8FromWide(const std::wstring& value);

/// Converts UTF-8 to UTF-16.
std::wstring WideFromUtf8(const std::string& value);

/// Returns the final path component of a Windows path.
std::string FileNameOf(const std::string& path);

/// Parses a flat `[left, top, right, bottom, ...]` list of physical pixels.
///
/// Returns no value when the length is not a multiple of four, which means
/// Dart and this code disagree about the wire format rather than that the app
/// has no drop regions.
std::optional<std::vector<Rect>> ParseRegions(const std::vector<double>& flat);

/// Whether any region contains the point.
bool AnyContains(const std::vector<Rect>& regions, double x, double y);

/// Reads the paths out of a `CF_HDROP` buffer.
///
/// Returns no value when the buffer is too small to hold its own header or
/// when the header points outside the buffer.
std::optional<std::vector<std::string>> ParseHdrop(const uint8_t* data,
                                                   size_t size);

/// Wraps a `CF_DIB` or `CF_DIBV5` payload in a BMP file header.
///
/// The clipboard stores a device-independent bitmap without the 14-byte file
/// header every image decoder expects, so this prepends one and computes the
/// pixel offset from the header size, the colour-mask fields, and the palette.
/// Returns no value when the payload cannot be a bitmap header.
std::optional<std::vector<uint8_t>> BmpFromDib(const uint8_t* data,
                                               size_t size);

/// Media type for a file name, or an empty string when unknown.
///
/// Windows reports no media type for a dropped file, and a consumer that wants
/// one should not have to re-derive it from an extension in every app.
std::string MimeFromFileName(const std::string& file_name);

}  // namespace dropwell

#endif  // FLUTTER_PLUGIN_DROPWELL_DATA_H_
