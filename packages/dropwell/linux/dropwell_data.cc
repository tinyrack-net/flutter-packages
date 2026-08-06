#include "dropwell_data.h"

#include <algorithm>
#include <cctype>
#include <sstream>

namespace dropwell {

namespace {

constexpr char kFileScheme[] = "file://";

int HexValue(char digit) {
  if (digit >= '0' && digit <= '9') return digit - '0';
  if (digit >= 'a' && digit <= 'f') return digit - 'a' + 10;
  if (digit >= 'A' && digit <= 'F') return digit - 'A' + 10;
  return -1;
}

/// Decodes the percent-escapes a URI uses for spaces and non-ASCII bytes.
///
/// An invalid escape is kept verbatim rather than dropped, because a file name
/// containing a stray `%` is legal and losing it would rename the user's file.
std::string PercentDecode(const std::string& value) {
  std::string decoded;
  decoded.reserve(value.size());
  for (size_t index = 0; index < value.size(); index++) {
    if (value[index] != '%' || index + 2 >= value.size()) {
      decoded.push_back(value[index]);
      continue;
    }
    const int high = HexValue(value[index + 1]);
    const int low = HexValue(value[index + 2]);
    if (high < 0 || low < 0) {
      decoded.push_back(value[index]);
      continue;
    }
    decoded.push_back(static_cast<char>(high * 16 + low));
    index += 2;
  }
  return decoded;
}

std::string PercentEncode(const std::string& value) {
  static constexpr char kHex[] = "0123456789ABCDEF";
  std::string encoded;
  encoded.reserve(value.size());
  for (const char character : value) {
    const unsigned char byte = static_cast<unsigned char>(character);
    const bool unreserved = std::isalnum(byte) != 0 || byte == '-' ||
                            byte == '_' || byte == '.' || byte == '~' ||
                            byte == '/';
    if (unreserved) {
      encoded.push_back(character);
      continue;
    }
    encoded.push_back('%');
    encoded.push_back(kHex[byte >> 4]);
    encoded.push_back(kHex[byte & 0x0F]);
  }
  return encoded;
}

std::string Trim(const std::string& value) {
  size_t begin = 0;
  size_t end = value.size();
  while (begin < end && (value[begin] == '\r' || value[begin] == '\n' ||
                         value[begin] == ' ' || value[begin] == '\t')) {
    begin++;
  }
  while (end > begin && (value[end - 1] == '\r' || value[end - 1] == '\n' ||
                         value[end - 1] == ' ' || value[end - 1] == '\t')) {
    end--;
  }
  return value.substr(begin, end - begin);
}

std::string LowerExtension(const std::string& file_name) {
  const size_t dot = file_name.find_last_of('.');
  if (dot == std::string::npos || dot + 1 >= file_name.size()) return {};
  std::string extension = file_name.substr(dot + 1);
  std::transform(extension.begin(), extension.end(), extension.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return extension;
}

}  // namespace

bool Rect::Contains(double x, double y) const {
  return x >= left && x < right && y >= top && y < bottom;
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

std::vector<std::string> ParseUriList(const std::string& payload) {
  std::vector<std::string> paths;
  std::istringstream stream(payload);
  std::string line;
  while (std::getline(stream, line)) {
    const std::string uri = Trim(line);
    // A leading '#' marks a comment line in the uri-list format.
    if (uri.empty() || uri[0] == '#') continue;
    if (uri.compare(0, sizeof(kFileScheme) - 1, kFileScheme) != 0) continue;
    std::string rest = uri.substr(sizeof(kFileScheme) - 1);
    // An authority component is either empty or "localhost"; anything else
    // names another machine, whose paths are not ours to open.
    if (!rest.empty() && rest[0] != '/') {
      const size_t slash = rest.find('/');
      if (slash == std::string::npos) continue;
      if (rest.substr(0, slash) != "localhost") continue;
      rest = rest.substr(slash);
    }
    if (rest.empty()) continue;
    paths.push_back(PercentDecode(rest));
  }
  return paths;
}

std::string BuildUriList(const std::vector<std::string>& paths) {
  std::string payload;
  for (const std::string& path : paths) {
    payload += kFileScheme;
    payload += PercentEncode(path);
    payload += "\r\n";
  }
  return payload;
}

std::string FileNameOf(const std::string& path) {
  const size_t separator = path.find_last_of('/');
  return separator == std::string::npos ? path : path.substr(separator + 1);
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
