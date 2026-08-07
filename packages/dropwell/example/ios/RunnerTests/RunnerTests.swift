import Flutter
import UIKit
import XCTest

@testable import dropwell

// The plugin's data handling is UIKit-free on purpose, so this target reaches
// all of it without a running app. UIPasteboard reports a uniform type
// identifier rather than a media type, and translating Apple's identifiers is
// the part a consumer should never have to repeat.

class DropwellDataTests: XCTestCase {

  func testFileNameOfTakesTheLastComponent() {
    XCTAssertEqual(DropwellData.fileNameOf("/tmp/dir/file.txt"), "file.txt")
    XCTAssertEqual(DropwellData.fileNameOf("file.txt"), "file.txt")
  }

  func testMimeFromFileNameMapsKnownExtensionsCaseInsensitively() {
    XCTAssertEqual(DropwellData.mimeFromFileName("a.PNG"), "image/png")
    XCTAssertEqual(DropwellData.mimeFromFileName("a.jpeg"), "image/jpeg")
    XCTAssertEqual(DropwellData.mimeFromFileName("a.md"), "text/plain")
  }

  func testMimeFromFileNameReturnsNothingRatherThanGuessing() {
    XCTAssertNil(DropwellData.mimeFromFileName("archive.xyz"))
    XCTAssertNil(DropwellData.mimeFromFileName("noextension"))
    XCTAssertNil(DropwellData.mimeFromFileName("trailing."))
  }

  func testMimeFromTypeIdentifierTranslatesAppleIdentifiers() {
    XCTAssertEqual(DropwellData.mimeFromTypeIdentifier("public.png"), "image/png")
    XCTAssertEqual(
      DropwellData.mimeFromTypeIdentifier("public.utf8-plain-text"), "text/plain")
    XCTAssertNil(DropwellData.mimeFromTypeIdentifier("com.example.unknown"))
  }

  func testDefaultFileNameMatchesTheMediaType() {
    XCTAssertEqual(
      DropwellData.defaultFileName(forMime: "image/png"), "pasted-image.png")
    XCTAssertEqual(
      DropwellData.defaultFileName(forMime: "image/jpeg"), "pasted-image.jpg")
    XCTAssertEqual(DropwellData.defaultFileName(forMime: nil), "pasted-file")
  }

  func testReadPasteboardReportsNothingForAnEmptyPasteboard() {
    let pasteboard = UIPasteboard.withUniqueName()
    defer { UIPasteboard.remove(withName: pasteboard.name) }

    XCTAssertTrue(DropwellPlugin.readPasteboard(pasteboard).isEmpty)
  }

  func testReadPasteboardReportsAPngAsBytes() {
    let pasteboard = UIPasteboard.withUniqueName()
    defer { UIPasteboard.remove(withName: pasteboard.name) }
    pasteboard.items = [["public.png": Data([1, 2, 3])]]

    let files = DropwellPlugin.readPasteboard(pasteboard)

    XCTAssertEqual(files.count, 1)
    XCTAssertEqual(files.first?["fileName"] as? String, "pasted-image.png")
    XCTAssertEqual(files.first?["mimeType"] as? String, "image/png")
    XCTAssertEqual(
      (files.first?["bytes"] as? FlutterStandardTypedData)?.data, Data([1, 2, 3]))
  }
}
