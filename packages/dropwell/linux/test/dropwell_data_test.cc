#include <gtest/gtest.h>

#include <string>
#include <vector>

#include "dropwell_data.h"

namespace dropwell {
namespace test {

TEST(Rect, ContainsIsTopLeftInclusive) {
  const Rect rect{0, 0, 10, 10};

  EXPECT_TRUE(rect.Contains(0, 0));
  EXPECT_TRUE(rect.Contains(9.9, 9.9));
  EXPECT_FALSE(rect.Contains(10, 10));
  EXPECT_FALSE(rect.Contains(5, -0.1));
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

TEST(ParseUriList, ReadsCrlfSeparatedFileUris) {
  const auto paths = ParseUriList("file:///tmp/a.txt\r\nfile:///tmp/b.png\r\n");

  ASSERT_EQ(paths.size(), 2u);
  EXPECT_EQ(paths[0], "/tmp/a.txt");
  EXPECT_EQ(paths[1], "/tmp/b.png");
}

TEST(ParseUriList, DecodesPercentEscapes) {
  const auto paths =
      ParseUriList("file:///tmp/my%20file%20%ED%95%9C%EA%B8%80.txt\r\n");

  ASSERT_EQ(paths.size(), 1u);
  EXPECT_EQ(FileNameOf(paths[0]), "my file \xED\x95\x9C\xEA\xB8\x80.txt");
}

TEST(ParseUriList, KeepsAStrayPercentVerbatim) {
  const auto paths = ParseUriList("file:///tmp/100%.txt\r\n");

  ASSERT_EQ(paths.size(), 1u);
  EXPECT_EQ(FileNameOf(paths[0]), "100%.txt");
}

TEST(ParseUriList, SkipsCommentsAndBlankLines) {
  const auto paths =
      ParseUriList("# a comment\r\n\r\nfile:///tmp/a.txt\r\n\r\n");

  ASSERT_EQ(paths.size(), 1u);
  EXPECT_EQ(paths[0], "/tmp/a.txt");
}

TEST(ParseUriList, AcceptsBareNewlines) {
  const auto paths = ParseUriList("file:///tmp/a.txt\nfile:///tmp/b.txt");

  EXPECT_EQ(paths.size(), 2u);
}

TEST(ParseUriList, AcceptsALocalhostAuthority) {
  const auto paths = ParseUriList("file://localhost/tmp/a.txt\r\n");

  ASSERT_EQ(paths.size(), 1u);
  EXPECT_EQ(paths[0], "/tmp/a.txt");
}

TEST(ParseUriList, SkipsAnotherMachinesFiles) {
  const auto paths = ParseUriList("file://otherhost/tmp/a.txt\r\n");

  EXPECT_TRUE(paths.empty());
}

TEST(ParseUriList, SkipsNonFileSchemes) {
  const auto paths =
      ParseUriList("https://example.com/a.txt\r\nfile:///tmp/a.txt\r\n");

  ASSERT_EQ(paths.size(), 1u);
  EXPECT_EQ(paths[0], "/tmp/a.txt");
}

TEST(ParseUriList, IgnoresAnEmptyPayload) {
  EXPECT_TRUE(ParseUriList("").empty());
  EXPECT_TRUE(ParseUriList("file://\r\n").empty());
}

TEST(BuildUriList, RoundTripsThroughParseUriList) {
  const std::vector<std::string> paths{"/tmp/a b.txt",
                                       "/tmp/\xED\x95\x9C\xEA\xB8\x80.png"};

  EXPECT_EQ(ParseUriList(BuildUriList(paths)), paths);
}

TEST(BuildUriList, EscapesSpacesButNotSeparators) {
  EXPECT_EQ(BuildUriList({"/tmp/a b.txt"}), "file:///tmp/a%20b.txt\r\n");
}

TEST(FileNameOf, TakesTheLastComponent) {
  EXPECT_EQ(FileNameOf("/tmp/dir/file.txt"), "file.txt");
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

}  // namespace test
}  // namespace dropwell
