import Cocoa
import FlutterMacOS
import XCTest

@testable import dropwell

// The plugin's data handling is AppKit-free on purpose, so this target reaches
// all of it without a window. The coordinate flip is the reason this file
// exists: AppKit measures from the bottom left and Flutter from the top left,
// and a drop landing in the mirrored region is the kind of bug that reads as
// "drag and drop just doesn't work on this platform".

class DropwellDataTests: XCTestCase {

  func testContainsIsTopLeftInclusive() {
    let rect = DropwellRect(left: 0, top: 0, right: 10, bottom: 10)

    XCTAssertTrue(rect.contains(x: 0, y: 0))
    XCTAssertTrue(rect.contains(x: 9.9, y: 9.9))
    XCTAssertFalse(rect.contains(x: 10, y: 10))
    XCTAssertFalse(rect.contains(x: 5, y: -0.1))
  }

  func testParseRegionsReadsGroupsOfFour() {
    let regions = DropwellData.parseRegions([0, 1, 2, 3, 4, 5, 6, 7])

    XCTAssertEqual(regions?.count, 2)
    XCTAssertEqual(
      regions?[1], DropwellRect(left: 4, top: 5, right: 6, bottom: 7))
  }

  func testParseRegionsAcceptsAnEmptyList() {
    XCTAssertEqual(DropwellData.parseRegions([])?.count, 0)
  }

  func testParseRegionsRejectsATruncatedRectangle() {
    XCTAssertNil(DropwellData.parseRegions([0, 1, 2]))
  }

  func testAnyContainsFindsAPointInASecondRegion() {
    let regions = [
      DropwellRect(left: 0, top: 0, right: 10, bottom: 10),
      DropwellRect(left: 100, top: 100, right: 200, bottom: 200),
    ]

    XCTAssertTrue(DropwellData.anyContains(regions, x: 150, y: 150))
    XCTAssertFalse(DropwellData.anyContains(regions, x: 50, y: 50))
    XCTAssertFalse(DropwellData.anyContains([], x: 0, y: 0))
  }

  func testPhysicalPointFlipsTheVerticalAxis() {
    let point = DropwellData.physicalPoint(
      viewPoint: CGPoint(x: 10, y: 90), viewHeight: 100, scale: 1)

    XCTAssertEqual(point.x, 10)
    XCTAssertEqual(point.y, 10)
  }

  func testPhysicalPointScalesAfterFlipping() {
    let point = DropwellData.physicalPoint(
      viewPoint: CGPoint(x: 10, y: 90), viewHeight: 100, scale: 2)

    XCTAssertEqual(point.x, 20)
    XCTAssertEqual(point.y, 20)
  }

  func testPhysicalPointMapsTheTopLeftCornerToTheOrigin() {
    let point = DropwellData.physicalPoint(
      viewPoint: CGPoint(x: 0, y: 100), viewHeight: 100, scale: 2)

    XCTAssertEqual(point.x, 0)
    XCTAssertEqual(point.y, 0)
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

  func testReadPasteboardReportsFileUrlsWithNamesAndTypes() {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("dropwell-tests", isDirectory: true)
    try? FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("notes.txt")
    try? Data("hello".utf8).write(to: file)

    let pasteboard = NSPasteboard(name: .init("dropwell.unit-test"))
    pasteboard.clearContents()
    pasteboard.writeObjects([file as NSURL])

    let files = DropwellPlugin.readPasteboard(pasteboard)

    XCTAssertEqual(files.count, 1)
    XCTAssertEqual(files.first?["fileName"] as? String, "notes.txt")
    XCTAssertEqual(files.first?["mimeType"] as? String, "text/plain")
    XCTAssertEqual(files.first?["path"] as? String, file.path)
  }

  func testReadPasteboardReportsNothingForAnEmptyPasteboard() {
    let pasteboard = NSPasteboard(name: .init("dropwell.unit-test-empty"))
    pasteboard.clearContents()

    XCTAssertTrue(DropwellPlugin.readPasteboard(pasteboard).isEmpty)
  }
}
