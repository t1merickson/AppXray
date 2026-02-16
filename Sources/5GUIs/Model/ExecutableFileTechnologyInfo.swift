//
//  ExecutableFileTechnologyInfo.swift
//  5 GUIs
//

import struct Foundation.URL
import struct SwiftUI.Image

enum PlatformType: String, Equatable {
  case macOS    = "macOS"
  case iOS      = "iOS"
  case catalyst = "Mac Catalyst"
  case unknown  = "Unknown"
}

struct ExecutableFileTechnologyInfo: Equatable {

  let fileURL        : URL

  var infoDictionary : InfoDict?
  var executableURL  : URL?
  var receiptURL     : URL?
  var appImage       : Image?
  var dependencies   = [ String ]()

  var embeddedExecutables  = [ ExecutableFileTechnologyInfo ]()

  var detectedTechnologies : DetectedTechnologies = []
  var platformType         : PlatformType = .unknown
}

extension ExecutableFileTechnologyInfo {

  var appName : String {
    infoDictionary?.displayName
      ?? infoDictionary?.name
      ?? executableURL?.lastPathComponent
      ?? "???"
  }

  var embeddedTechnologies : DetectedTechnologies {
    var techs = DetectedTechnologies()
    for info in embeddedExecutables {
      techs.formUnion(info.detectedTechnologies)
    }
    return techs
  }

  /// All technologies from this app and its embedded executables combined.
  var allTechnologies: DetectedTechnologies {
    detectedTechnologies.union(embeddedTechnologies)
  }
}
