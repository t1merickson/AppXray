//
//  SummaryView.swift
//  5 GUIs
//
//  Copyright (c) 2020 ZeeZide GmbH. All rights reserved.
//

import SwiftUI

/**
 * After all detection badges are shown, we present a summary.
 */
struct SummaryView: View {

  let info : ExecutableFileTechnologyInfo

  var body: some View {
    HStack {
      Text(verbatim: info.summaryText)
        .padding(16)
    }
    .font(.callout)
    .foregroundColor(Color(NSColor.textColor))
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(NSColor.textBackgroundColor))
    )
  }
}

fileprivate struct Texts {

  static let none     = "Crazy, we couldn't detect any technology?!"
  static let fallback = "We don't have any words for this combination!"

  // Electron
  static let electronAndCatalyst =
    "This app uses Electron AND Catalyst. What a strange combo."
  static let electronAndSwiftUI =
    "Uses Electron and SwiftUI. This app might be a proper native app soon!"
  static let electron =
    "An Electron app. Chrome under the hood, Node.js at the wheel."

  // CEF
  static let cef =
    "Uses the Chromium Embedded Framework. Chromium without the Node.js."

  // Catalyst
  static let catalyst =
    "A macOS Catalyst app, i.e. a mobile app " +
    "longing for larger screens w/o touch (yet?)."

  // iOS on Mac
  static let iOSOnMac =
    "This is an iPhone or iPad app running on Apple silicon."

  // SwiftUI
  static let swiftui =
    "SwiftUI. Respect! " +
    "The developer of this app likes to live on the bleeding edge."

  // AppKit
  static let appKitSwift =
    "An AppKit app. But a modern one! This app is using Swift."
  static let appKitObjC =
    "A gem! This app looks like a trustworthy AppKit Objective-C app. " +
    "No experiments, please!"

  // Flutter
  static let flutter =
    "A Flutter app. Dart code compiled to native, with its own rendering engine."

  // Tauri
  static let tauri =
    "A Tauri app. Rust backend with a native WebView frontend. Lightweight."

  // React Native
  static let reactNative =
    "A React Native app. JavaScript meets native views."

  // Capacitor
  static let capacitor =
    "A Capacitor/Ionic app. Web technologies in a native shell."

  // Qt
  static let qtPython =
    "A Qt app written in Python. Cross-platform with a scripting twist."
  static let qt =
    "Qt. A cross-platform C++ framework. Anything can happen."

  // wxWidgets
  static let wxWidgetsPython =
    "wxWidgets with Python. Very cross-platform!"
  static let wxWidgets =
    "wxWidgets. Could be Python, Perl, Ruby, or straight C++."

  // Java
  static let java =
    "Java. An actual app built using Java."

  // Python
  static let python =
    "A Python app. Hope all indents are right."

  // Unity
  static let unity =
    "A Unity app. Game engine territory. Mono or IL2CPP under the hood."

  // Godot
  static let godot =
    "A Godot Engine app. Open-source game development."

  // Unreal
  static let unreal =
    "An Unreal Engine app. Heavy-duty game engine."

  // .NET
  static let dotnet =
    "A .NET app. The CLR runtime on macOS."

  // Avalonia
  static let avalonia =
    "An Avalonia UI app. Cross-platform .NET with a XAML-based UI."

  // Mono
  static let mono =
    "Uses Mono. The open-source .NET runtime, possibly Xamarin."

  // Rust
  static let rust =
    "A Rust application. Memory-safe and fast."

  // Automator
  static let automatorApp =
    "An Automator app. " +
    "We've finally found someone using that great technology!"

  // AppleScript
  static let applescriptApp =
    "tell application \"#APPNAME#\" it is an AppleScript application!"

  // Platypus
  static let platypusApp =
    "#!/usr/local/bin/platypus: Looks like a script packaged with Platypus!"
}

import Foundation

fileprivate extension ExecutableFileTechnologyInfo {

  var summaryText : String {
    summaryTextTemplate.replacingOccurrences(of: "#APPNAME#", with: appName)
  }

  private var summaryTextTemplate : String {
    let allTechnologies = self.allTechnologies

    func features(_ feature: DetectedTechnologies) -> Bool {
      allTechnologies.contains(feature)
    }

    if allTechnologies.isEmpty { return Texts.none }

    // Electron family
    if features(.electron) {
      if features(.catalyst) { return Texts.electronAndCatalyst }
      if features(.swift)    { return Texts.electronAndSwiftUI  }
      return Texts.electron
    }

    // CEF (non-Electron Chromium)
    if features(.cef) {
      return Texts.cef
    }

    // Automator
    if (infoDictionary?.isAutomatorApplet ?? false) {
      return Texts.automatorApp
    }

    // Catalyst
    if features(.catalyst) {
      return Texts.catalyst
    }

    // iOS on Mac
    if features(.iOSOnMac) {
      return Texts.iOSOnMac
    }

    // Native iPhone/iPad app (UIKit without Catalyst or iOSOnMac)
    if !features(.catalyst) && features(.uikit) && !features(.appkit)
       && !features(.iOSOnMac) {
      return Texts.iOSOnMac
    }

    // Tauri
    if features(.tauri) {
      return Texts.tauri
    }

    // Flutter
    if features(.flutter) {
      return Texts.flutter
    }

    // React Native
    if features(.reactNative) {
      return Texts.reactNative
    }

    // Capacitor / Ionic
    if features(.capacitor) {
      return Texts.capacitor
    }

    // Game engines
    if features(.unity)  { return Texts.unity  }
    if features(.godot)  { return Texts.godot  }
    if features(.unreal) { return Texts.unreal }

    // Java
    if features(.java) {
      return Texts.java
    }

    // SwiftUI
    if features(.swiftui) {
      return Texts.swiftui
    }

    // Qt
    if features(.qt) {
      if features(.python) { return Texts.qtPython }
      return Texts.qt
    }

    // wxWidgets
    if features(.wxWidgets) {
      if features(.python) { return Texts.wxWidgetsPython }
      return Texts.wxWidgets
    }

    // .NET family
    if features(.avalonia) { return Texts.avalonia }
    if features(.dotnet)   { return Texts.dotnet   }
    if features(.mono)     { return Texts.mono     }

    // Python
    if features(.python) {
      return Texts.python
    }

    // Rust (standalone, not Tauri)
    if features(.rust) {
      return Texts.rust
    }

    // AppleScript
    if features(.applescript) && infoDictionary?.executable == "applet" {
      return Texts.applescriptApp
    }

    // Platypus
    if features(.platypus) && !features(.swift) {
      return Texts.platypusApp
    }

    // AppKit
    if features(.appkit) {
      if features(.swift) { return Texts.appKitSwift }
      return Texts.appKitObjC
    }

    return Texts.fallback
  }
}
