#ifndef FLUTTER_PLUGIN_DROPWELL_DATA_H_
#define FLUTTER_PLUGIN_DROPWELL_DATA_H_

// Pure data handling for the Linux implementation.
//
// Nothing here touches Flutter, GTK, or a display, so all of it is reachable
// from the googletest binary on a headless runner. The `text/uri-list` parsing
// in particular is where a Linux file drop goes wrong: the format is CRLF
// separated, allows comment lines, and percent-encodes every character a file
// name is likely to contain, so a naive split loses exactly the files whose
// names people complain about.

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

/// Parses a flat `[left, top, right, bottom, ...]` list of physical pixels.
std::optional<std::vector<Rect>> ParseRegions(const std::vector<double>& flat);

/// Whether any region contains the point.
bool AnyContains(const std::vector<Rect>& regions, double x, double y);

/// Decodes a `text/uri-list` payload into absolute paths.
///
/// Non-`file:` URIs are dropped rather than reported as paths that do not
/// exist; a consumer asked for files and a remote URI is not one.
std::vector<std::string> ParseUriList(const std::string& payload);

/// Encodes absolute paths as a `text/uri-list` payload.
std::string BuildUriList(const std::vector<std::string>& paths);

/// Returns the final path component.
std::string FileNameOf(const std::string& path);

/// Media type for a file name, or an empty string when unknown.
std::string MimeFromFileName(const std::string& file_name);

}  // namespace dropwell

#endif  // FLUTTER_PLUGIN_DROPWELL_DATA_H_
