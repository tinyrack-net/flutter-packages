import Cocoa
import FlutterMacOS
import XCTest

final class RunnerTests: XCTestCase {
  func testMarkedTextReplacementCommitsOnlyFinalValue() {
    let updates: [(String, Bool)] = [
      ("ㅎ", true), ("한글", true), ("韓國", true), ("韓國", false),
    ]
    let commits = updates.filter { !$0.1 }.map { $0.0 }

    XCTAssertEqual(commits, ["韓國"])
    XCTAssertEqual("👩🏽‍💻".count, 1)
  }
}
