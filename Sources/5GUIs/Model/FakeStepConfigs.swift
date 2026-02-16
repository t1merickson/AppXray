//
//  FakeStepConfigs.swift
//  5 GUIs
//
//  Copyright (c) 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * The data for the configurations which show up as badges in the UI,
 * i.e. the features (GUI frameworks) we test.
 *
 * Note that there are also `FakeStep`s, which also contain the info
 * whether or not the feature is available or not.
 */
struct FakeStepConfig : Equatable, Identifiable {

  let id                : Int
  let runTitle          : String
  let positiveTitle     : String
  let positiveCheckmark : String
  let negativeTitle     : String
  let negativeCheckmark : String

  static let electron = FakeStepConfig(
    id                : 1,
    runTitle          : "Checking for Electron ...",
    positiveTitle     : "Electron detected. Chromium and Node.js inside.",
    positiveCheckmark : "[!]",
    negativeTitle     : "No Electron detected.",
    negativeCheckmark : "[ok]"
  )
  static let catalyst = FakeStepConfig(
    id                : 2,
    runTitle          : "Checking for Catalyst ...",
    positiveTitle     : "Uses macOS Catalyst. A mobile app on the desktop.",
    positiveCheckmark : "[!]",
    negativeTitle     : "No Catalyst detected.",
    negativeCheckmark : "[ok]"
  )
  static let swiftUI = FakeStepConfig(
    id                : 3,
    runTitle          : "Checking for SwiftUI ...",
    positiveTitle     : "SwiftUI detected. Declarative and modern.",
    positiveCheckmark : "[*]",
    negativeTitle     : "No SwiftUI in use.",
    negativeCheckmark : "[-]"
  )
  static let phone = FakeStepConfig(
    id                : 4,
    runTitle          : "Checking for iOS app ...",
    positiveTitle     : "This is an iPhone or iPad app running on Mac.",
    positiveCheckmark : "[!]",
    negativeTitle     : "Not an iOS app.",
    negativeCheckmark : "[ok]"
  )
  static let appKit = FakeStepConfig(
    id                : 5,
    runTitle          : "Checking for AppKit ...",
    positiveTitle     : "AppKit detected. Classic macOS native.",
    positiveCheckmark : "[*]",
    negativeTitle     : "No AppKit detected.",
    negativeCheckmark : "[-]"
  )

  static let all : [ FakeStepConfig ] = [
    .electron, .catalyst, .swiftUI, .phone, .appKit
  ]
}

extension ExecutableFileTechnologyInfo {

  /// The "5 GUIs" badge analysis results.
  var analysisResults : [ FakeStep ] {
    let allTechs = self.allTechnologies

    func make(_ feature : DetectedTechnologies, _ config  : FakeStepConfig)
         -> FakeStep
    {
      .init(config: config, state: allTechs.contains(feature))
    }

    let isPhone = allTechs.contains(.uikit)
             && !(allTechs.contains(.catalyst))
             || allTechs.contains(.iOSOnMac)

    return [
      make(.electron, .electron),
      make(.catalyst, .catalyst),
      make(.swiftui,  .swiftUI),
      .init(config: .phone, state: isPhone),
      make(.appkit, .appKit)
    ]
  }
}
