#include <gtest/gtest.h>

#include <cstring>
#include <string>
#include <vector>

#include "dropwell_data.h"

namespace dropwell {
namespace test {
namespace {

std::vector<uint8_t> BuildHdrop(const std::vector<std::wstring>& paths) {
  std::vector<uint8_t> buffer(20, 0);
  const uint32_t offset = 20;
  std::memcpy(buffer.data(), &offset, sizeof(offset));
  const uint32_t wide = 1;
  std::memcpy(buffer.data() + 16, &wide, sizeof(wide));
  for (const std::wstring& path : paths) {
    const uint8_t* bytes = reinterpret_cast<const uint8_t*>(path.c_str());
    buffer.insert(buffer.end(), bytes,
                  bytes + (path.size() + 1) * sizeof(wchar_t));
  }
  buffer.push_back(0);
  buffer.push_back(0);
  return buffer;
}

std::vector<uint8_t> BuildInfoHeader(uint16_t bit_count, uint32_t compression,
                                     uint32_t colors_used,
                                     uint32_t header_size = 40) {
  std::vector<uint8_t> header(header_size, 0);
  std::memcpy(header.data(), &header_size, sizeof(header_size));
  std::memcpy(header.data() + 14, &bit_count, sizeof(bit_count));
  std::memcpy(header.data() + 16, &compression, sizeof(compression));
  std::memcpy(header.data() + 32, &colors_used, sizeof(colors_used));
  header.resize(header_size + 16, 0xAB);  // Stand-in pixel data.
  return header;
}

uint32_t PixelOffsetOf(const std::vector<uint8_t>& bmp) {
  uint32_t offset = 0;
  std::memcpy(&offset, bmp.data() + 10, sizeof(offset));
  return offset;
}

}  // namespace

TEST(Rect, ContainsIsTopLeftInclusive) {
  const Rect rect{0, 0, 10, 10};

  EXPECT_TRUE(rect.Contains(0, 0));
  EXPECT_TRUE(rect.Contains(9.9, 9.9));
  EXPECT_FALSE(rect.Contains(10, 10));
  EXPECT_FALSE(rect.Contains(-0.1, 5));
}

TEST(ParseRegions, ReadsGroupsOfFour) {
  const auto regions = ParseRegions({0, 1, 2, 3, 4, 5, 6, 7});

  ASSERT_TRUE(regions.has_value());
  ASSERT_EQ(regions->size(), 2u);
  EXPECT_DOUBLE_EQ((*regions)[1].left, 4);
  EXPECT_DOUBLE_EQ((*regions)[1].bottom, 7);
}

TEST(ParseRegions, AcceptsAnEmptyList) {
  const auto regions = ParseRegions({});

  ASSERT_TRUE(regions.has_value());
  EXPECT_TRUE(regions->empty());
}

TEST(ParseRegions, RejectsATruncatedRectangle) {
  EXPECT_FALSE(ParseRegions({0, 1, 2}).has_value());
}

TEST(AnyContains, FindsAPointInASecondRegion) {
  const std::vector<Rect> regions{{0, 0, 10, 10}, {100, 100, 200, 200}};

  EXPECT_TRUE(AnyContains(regions, 150, 150));
  EXPECT_FALSE(AnyContains(regions, 50, 50));
  EXPECT_FALSE(AnyContains({}, 0, 0));
}

TEST(ParseHdrop, ReadsEveryWidePath) {
  const auto buffer = BuildHdrop({L"C:\\a.txt", L"C:\\dir\\b.png"});

  const auto paths = ParseHdrop(buffer.data(), buffer.size());

  ASSERT_TRUE(paths.has_value());
  ASSERT_EQ(paths->size(), 2u);
  EXPECT_EQ((*paths)[0], "C:\\a.txt");
  EXPECT_EQ((*paths)[1], "C:\\dir\\b.png");
}

TEST(ParseHdrop, KeepsNonAsciiAndAstralCharacters) {
  const auto buffer = BuildHdrop({L"C:\\\uD55C\uAE00 \uC774\uB984 \U0001F4C4.txt"});

  const auto paths = ParseHdrop(buffer.data(), buffer.size());

  ASSERT_TRUE(paths.has_value());
  ASSERT_EQ(paths->size(), 1u);
  EXPECT_EQ(FileNameOf((*paths)[0]),
            Utf8FromWide(L"\uD55C\uAE00 \uC774\uB984 \U0001F4C4.txt"));
}

TEST(ParseHdrop, StopsAtTheDoubleNullTerminator) {
  auto buffer = BuildHdrop({L"C:\\a.txt"});
  buffer.insert(buffer.end(), 8, 0);

  const auto paths = ParseHdrop(buffer.data(), buffer.size());

  ASSERT_TRUE(paths.has_value());
  EXPECT_EQ(paths->size(), 1u);
}

TEST(ParseHdrop, RejectsABufferSmallerThanItsHeader) {
  const std::vector<uint8_t> buffer(8, 0);

  EXPECT_FALSE(ParseHdrop(buffer.data(), buffer.size()).has_value());
  EXPECT_FALSE(ParseHdrop(nullptr, 100).has_value());
}

TEST(ParseHdrop, RejectsAnOffsetOutsideTheBuffer) {
  auto buffer = BuildHdrop({L"C:\\a.txt"});
  const uint32_t offset = static_cast<uint32_t>(buffer.size() + 1);
  std::memcpy(buffer.data(), &offset, sizeof(offset));

  EXPECT_FALSE(ParseHdrop(buffer.data(), buffer.size()).has_value());
}

TEST(ParseHdrop, RejectsAnOffsetInsideItsOwnHeader) {
  auto buffer = BuildHdrop({L"C:\\a.txt"});
  const uint32_t offset = 4;
  std::memcpy(buffer.data(), &offset, sizeof(offset));

  EXPECT_FALSE(ParseHdrop(buffer.data(), buffer.size()).has_value());
}

TEST(BmpFromDib, PlacesPixelsAfterTheHeaderForATrueColourBitmap) {
  const auto dib = BuildInfoHeader(32, 0, 0);

  const auto bmp = BmpFromDib(dib.data(), dib.size());

  ASSERT_TRUE(bmp.has_value());
  EXPECT_EQ((*bmp)[0], 'B');
  EXPECT_EQ((*bmp)[1], 'M');
  EXPECT_EQ(PixelOffsetOf(*bmp), 14u + 40u);
  EXPECT_EQ(bmp->size(), 14u + dib.size());
}

TEST(BmpFromDib, SkipsAnImplicitPaletteForAnIndexedBitmap) {
  const auto dib = BuildInfoHeader(8, 0, 0);

  const auto bmp = BmpFromDib(dib.data(), dib.size());

  ASSERT_TRUE(bmp.has_value());
  EXPECT_EQ(PixelOffsetOf(*bmp), 14u + 40u + 256u * 4u);
}

TEST(BmpFromDib, HonoursAnExplicitPaletteSize) {
  const auto dib = BuildInfoHeader(8, 0, 16);

  const auto bmp = BmpFromDib(dib.data(), dib.size());

  ASSERT_TRUE(bmp.has_value());
  EXPECT_EQ(PixelOffsetOf(*bmp), 14u + 40u + 16u * 4u);
}

TEST(BmpFromDib, AddsChannelMasksOnlyForAVersionThreeHeader) {
  const auto v3 = BuildInfoHeader(32, 3, 0);
  const auto v5 = BuildInfoHeader(32, 3, 0, 124);

  const auto from_v3 = BmpFromDib(v3.data(), v3.size());
  const auto from_v5 = BmpFromDib(v5.data(), v5.size());

  ASSERT_TRUE(from_v3.has_value());
  ASSERT_TRUE(from_v5.has_value());
  EXPECT_EQ(PixelOffsetOf(*from_v3), 14u + 40u + 12u);
  EXPECT_EQ(PixelOffsetOf(*from_v5), 14u + 124u);
}

TEST(BmpFromDib, RejectsAHeaderSmallerThanAnyKnownBitmapHeader) {
  const std::vector<uint8_t> dib{4, 0, 0, 0, 1, 2, 3, 4};

  EXPECT_FALSE(BmpFromDib(dib.data(), dib.size()).has_value());
}

TEST(BmpFromDib, RejectsAHeaderLargerThanItsBuffer) {
  std::vector<uint8_t> dib(20, 0);
  const uint32_t header_size = 40;
  std::memcpy(dib.data(), &header_size, sizeof(header_size));

  EXPECT_FALSE(BmpFromDib(dib.data(), dib.size()).has_value());
  EXPECT_FALSE(BmpFromDib(nullptr, 100).has_value());
}

TEST(FileNameOf, TakesTheLastComponent) {
  EXPECT_EQ(FileNameOf("C:\\dir\\file.txt"), "file.txt");
  EXPECT_EQ(FileNameOf("C:/dir/file.txt"), "file.txt");
  EXPECT_EQ(FileNameOf("file.txt"), "file.txt");
}

TEST(MimeFromFileName, MapsKnownExtensionsCaseInsensitively) {
  EXPECT_EQ(MimeFromFileName("a.PNG"), "image/png");
  EXPECT_EQ(MimeFromFileName("a.jpeg"), "image/jpeg");
  EXPECT_EQ(MimeFromFileName("a.md"), "text/plain");
}

TEST(MimeFromFileName, ReturnsNothingRatherThanGuessing) {
  EXPECT_EQ(MimeFromFileName("archive.xyz"), "");
  EXPECT_EQ(MimeFromFileName("noextension"), "");
  EXPECT_EQ(MimeFromFileName("trailing."), "");
}

TEST(WideFromUtf8, RoundTripsThroughUtf8) {
  const std::wstring original = L"\uD55C\uAE00 \U0001F4C4.txt";

  EXPECT_EQ(WideFromUtf8(Utf8FromWide(original)), original);
  EXPECT_TRUE(Utf8FromWide(L"").empty());
  EXPECT_TRUE(WideFromUtf8("").empty());
}

}  // namespace test
}  // namespace dropwell
