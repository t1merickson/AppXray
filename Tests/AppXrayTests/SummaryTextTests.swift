import Foundation
import XCTest

final class SummaryTextTests: XCTestCase {
  private func info(_ technologies: DetectedTechnologies)
    -> ExecutableFileTechnologyInfo
  {
    var info = ExecutableFileTechnologyInfo(
      fileURL: URL(fileURLWithPath: "/tmp/Fake.app"))
    info.detectedTechnologies = technologies
    return info
  }

  func testEmptyTechnologiesUseNoneSummary() {
    XCTAssertEqual(info([]).summaryText, "No technologies detected.")
  }

  func testElectronSummaryHasPriorityOverSwiftUI() {
    XCTAssertEqual(
      info([.electron, .swiftui]).summaryText,
      "Uses Electron alongside SwiftUI.")
  }

  func testAppKitSwiftSummary() {
    XCTAssertEqual(
      info([.appkit, .swift]).summaryText,
      "An AppKit app written in Swift.")
  }

  func testAppKitObjectiveCSummary() {
    XCTAssertEqual(
      info([.appkit, .objc]).summaryText,
      "An AppKit app written in Objective-C.")
  }

  func testQtPythonSummary() {
    XCTAssertEqual(
      info([.qt, .python]).summaryText,
      "A Qt app written in Python.")
  }

  func testEmbeddedTechnologiesContributeToSummary() {
    var parent = info([])
    parent.embeddedExecutables = [info(.electron)]

    XCTAssertEqual(
      parent.summaryText,
      "An Electron app. Chromium and Node.js under the hood.")
  }
}
