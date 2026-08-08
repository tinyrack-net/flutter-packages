import Flutter
import UIKit
import XCTest

final class RunnerTests: XCTestCase {
  func testTextInputBoundaryPreservesComposedSequences() {
    let value = "한글👩🏽‍💻e\u{0301}"
    let clusters = value.map(String.init)
    let data = value.data(using: .utf16LittleEndian)

    XCTAssertEqual(clusters, ["한", "글", "👩🏽‍💻", "é"])
    XCTAssertEqual(String(data: data!, encoding: .utf16LittleEndian), value)
  }
}
