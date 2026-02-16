//
//  SummaryView.swift
//  5 GUIs
//

import SwiftUI

struct SummaryView: View {

  let info: ExecutableFileTechnologyInfo

  var body: some View {
    Text(verbatim: info.summaryText)
      .font(.callout)
      .foregroundColor(.secondary)
      .multilineTextAlignment(.center)
      .padding(.top, 8)
  }
}

fileprivate struct Texts {

  static let none     = "No technologies detected."
  static let fallback = "Could not determine the primary technology."

  static let electronAndCatalyst =
    "Uses both Electron and Catalyst."
  static let electronAndSwiftUI =
    "Uses Electron alongside SwiftUI."
  static let electron =
    "An Electron app. Chromium and Node.js under the hood."

  static let cef =
    "Uses the Chromium Embedded Framework."

  static let catalyst =
    "A Mac Catalyst app. Originally built for iOS."

  static let iOSOnMac =
    "An iPhone or iPad app running on Apple silicon."

  static let swiftui =
    "A SwiftUI application."

  static let appKitSwift =
    "An AppKit app written in Swift."
  static let appKitObjC =
    "An AppKit app written in Objective-C."

  static let flutter =
    "A Flutter app. Dart compiled to native with its own rendering engine."

  static let tauri =
    "A Tauri app. Rust backend with a native WebView frontend."

  static let reactNative =
    "A React Native app. JavaScript driving native views."

  static let capacitor =
    "A Capacitor app. Web technologies in a native shell."

  static let qtPython =
    "A Qt app written in Python."
  static let qt =
    "A Qt app. Cross-platform C++ framework."

  static let wxWidgetsPython =
    "A wxWidgets app written in Python."
  static let wxWidgets =
    "A wxWidgets app. Cross-platform native widgets."

  static let java =
    "A Java application."

  static let python =
    "A Python application."

  static let unity =
    "A Unity app. Mono or IL2CPP runtime."

  static let godot =
    "A Godot Engine application."

  static let unreal =
    "An Unreal Engine application."

  static let dotnet =
    "A .NET application running on the CLR."

  static let avalonia =
    "An Avalonia UI app. Cross-platform .NET with XAML."

  static let mono =
    "Uses the Mono runtime."

  static let rust =
    "A Rust application."

  static let automatorApp =
    "An Automator applet."

  static let applescriptApp =
    "An AppleScript application."

  static let platypusApp =
    "A script packaged with Platypus."
}

import Foundation

fileprivate extension ExecutableFileTechnologyInfo {

  var summaryText: String {
    summaryTextTemplate
  }

  private var summaryTextTemplate: String {
    let allTechnologies = self.allTechnologies

    func features(_ feature: DetectedTechnologies) -> Bool {
      allTechnologies.contains(feature)
    }

    if allTechnologies.isEmpty { return Texts.none }

    if features(.electron) {
      if features(.catalyst) { return Texts.electronAndCatalyst }
      if features(.swiftui)  { return Texts.electronAndSwiftUI  }
      return Texts.electron
    }

    if features(.cef) { return Texts.cef }

    if (infoDictionary?.isAutomatorApplet ?? false) {
      return Texts.automatorApp
    }

    if features(.catalyst) { return Texts.catalyst }
    if features(.iOSOnMac) { return Texts.iOSOnMac }

    if !features(.catalyst) && features(.uikit) && !features(.appkit)
       && !features(.iOSOnMac) {
      return Texts.iOSOnMac
    }

    if features(.tauri)       { return Texts.tauri       }
    if features(.flutter)     { return Texts.flutter     }
    if features(.reactNative) { return Texts.reactNative }
    if features(.capacitor)   { return Texts.capacitor   }

    if features(.unity)  { return Texts.unity  }
    if features(.godot)  { return Texts.godot  }
    if features(.unreal) { return Texts.unreal }

    if features(.java) { return Texts.java }

    if features(.swiftui) { return Texts.swiftui }

    if features(.qt) {
      if features(.python) { return Texts.qtPython }
      return Texts.qt
    }

    if features(.wxWidgets) {
      if features(.python) { return Texts.wxWidgetsPython }
      return Texts.wxWidgets
    }

    if features(.avalonia) { return Texts.avalonia }
    if features(.dotnet)   { return Texts.dotnet   }
    if features(.mono)     { return Texts.mono     }

    if features(.python) { return Texts.python }
    if features(.rust)   { return Texts.rust   }

    if features(.applescript) && infoDictionary?.executable == "applet" {
      return Texts.applescriptApp
    }

    if features(.platypus) && !features(.swift) {
      return Texts.platypusApp
    }

    if features(.appkit) {
      if features(.swift) { return Texts.appKitSwift }
      return Texts.appKitObjC
    }

    return Texts.fallback
  }
}
