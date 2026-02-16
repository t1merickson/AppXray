//
//  DetectedTechnologies.swift
//  5GUIs
//
//  Created by Helge Hess on 05.10.20.
//

struct DetectedTechnologies: OptionSet, Sendable {
  let rawValue: UInt64

  // MARK: - Apple Platform Frameworks (bits 1-9)

  static let carbon      = DetectedTechnologies(rawValue: 1 << 1)
  static let appkit      = DetectedTechnologies(rawValue: 1 << 2)
  static let automator   = DetectedTechnologies(rawValue: 1 << 3)
  static let webkit      = DetectedTechnologies(rawValue: 1 << 4)
  static let uikit       = DetectedTechnologies(rawValue: 1 << 5)
  static let swiftui     = DetectedTechnologies(rawValue: 1 << 6)
  static let iOSOnMac    = DetectedTechnologies(rawValue: 1 << 7)

  // MARK: - Third-Party Frameworks (bits 10-19)

  static let electron    = DetectedTechnologies(rawValue: 1 << 10)
  static let catalyst    = DetectedTechnologies(rawValue: 1 << 11)
  static let qt          = DetectedTechnologies(rawValue: 1 << 12)
  static let wxWidgets   = DetectedTechnologies(rawValue: 1 << 13)
  static let platypus    = DetectedTechnologies(rawValue: 1 << 14)
  static let cef         = DetectedTechnologies(rawValue: 1 << 15)
  static let flutter     = DetectedTechnologies(rawValue: 1 << 16)
  static let tauri       = DetectedTechnologies(rawValue: 1 << 17)
  static let reactNative = DetectedTechnologies(rawValue: 1 << 18)
  static let capacitor   = DetectedTechnologies(rawValue: 1 << 19)

  // MARK: - Languages (bits 20-29)

  static let objc        = DetectedTechnologies(rawValue: 1 << 20)
  static let swift       = DetectedTechnologies(rawValue: 1 << 21)
  static let cplusplus   = DetectedTechnologies(rawValue: 1 << 22)
  static let python      = DetectedTechnologies(rawValue: 1 << 23)
  static let java        = DetectedTechnologies(rawValue: 1 << 24)
  static let applescript = DetectedTechnologies(rawValue: 1 << 25)
  static let rust        = DetectedTechnologies(rawValue: 1 << 26)
  static let javascript  = DetectedTechnologies(rawValue: 1 << 27)

  // MARK: - Game Engines & Runtimes (bits 30-39)

  static let unity       = DetectedTechnologies(rawValue: 1 << 30)
  static let godot       = DetectedTechnologies(rawValue: 1 << 31)
  static let unreal      = DetectedTechnologies(rawValue: 1 << 32)
  static let dotnet      = DetectedTechnologies(rawValue: 1 << 33)
  static let avalonia    = DetectedTechnologies(rawValue: 1 << 34)
  static let mono        = DetectedTechnologies(rawValue: 1 << 35)
}

// MARK: - Display Names

extension DetectedTechnologies {

  /// All individual technology flags for iteration.
  static let allKnown: [DetectedTechnologies] = [
    .carbon, .appkit, .automator, .webkit, .uikit, .swiftui, .iOSOnMac,
    .electron, .catalyst, .qt, .wxWidgets, .platypus, .cef, .flutter,
    .tauri, .reactNative, .capacitor,
    .objc, .swift, .cplusplus, .python, .java, .applescript, .rust, .javascript,
    .unity, .godot, .unreal, .dotnet, .avalonia, .mono,
  ]

  var displayName: String? {
    // Only returns a name for single-bit values
    switch self {
    case .carbon:       return "Carbon"
    case .appkit:       return "AppKit"
    case .automator:    return "Automator"
    case .webkit:       return "WebKit"
    case .uikit:        return "UIKit"
    case .swiftui:      return "SwiftUI"
    case .iOSOnMac:     return "iOS on Mac"
    case .electron:     return "Electron"
    case .catalyst:     return "Mac Catalyst"
    case .qt:           return "Qt"
    case .wxWidgets:    return "wxWidgets"
    case .platypus:     return "Platypus"
    case .cef:          return "CEF (Chromium)"
    case .flutter:      return "Flutter"
    case .tauri:        return "Tauri"
    case .reactNative:  return "React Native"
    case .capacitor:    return "Capacitor"
    case .objc:         return "Objective-C"
    case .swift:        return "Swift"
    case .cplusplus:    return "C++"
    case .python:       return "Python"
    case .java:         return "Java"
    case .applescript:  return "AppleScript"
    case .rust:         return "Rust"
    case .javascript:   return "JavaScript"
    case .unity:        return "Unity"
    case .godot:        return "Godot"
    case .unreal:       return "Unreal Engine"
    case .dotnet:       return ".NET"
    case .avalonia:     return "Avalonia"
    case .mono:         return "Mono"
    default:            return nil
    }
  }

  /// SF Symbol name for this technology (macOS 12+ / SF Symbols 3 safe).
  var symbolName: String {
    switch self {
    // Apple Platform Frameworks
    case .carbon:       return "desktopcomputer"
    case .appkit:       return "macwindow"
    case .automator:    return "gearshape.2"
    case .webkit:       return "globe"
    case .uikit:        return "iphone"
    case .swiftui:      return "swift"
    case .iOSOnMac:     return "apps.iphone"
    // Third-Party Frameworks
    case .electron:     return "bolt.fill"
    case .catalyst:     return "arrow.triangle.2.circlepath"
    case .qt:           return "cube"
    case .wxWidgets:    return "macwindow.on.rectangle"
    case .platypus:     return "doc.text"
    case .cef:          return "globe"
    case .flutter:      return "paintbrush"
    case .tauri:        return "shield.lefthalf.filled"
    case .reactNative:  return "arrow.triangle.branch"
    case .capacitor:    return "bolt.square"
    // Languages
    case .objc:         return "c.square"
    case .swift:        return "swift"
    case .cplusplus:    return "chevron.left.forwardslash.chevron.right"
    case .python:       return "number"
    case .java:         return "cup.and.saucer.fill"
    case .applescript:  return "applescript"
    case .rust:         return "gearshape"
    case .javascript:   return "ellipsis.curlybraces"
    // Runtimes / Engines
    case .unity:        return "gamecontroller"
    case .godot:        return "gamecontroller"
    case .unreal:       return "gamecontroller.fill"
    case .dotnet:       return "network"
    case .avalonia:     return "rectangle.on.rectangle"
    case .mono:         return "square.stack.3d.up"
    default:            return "questionmark.app"
    }
  }

  /// Returns the individual technologies present as display name strings.
  var detectedNames: [String] {
    Self.allKnown.compactMap { flag in
      self.contains(flag) ? flag.displayName : nil
    }
  }
}

// MARK: - Category Grouping

/// A single detected technology with its display name and icon.
struct TechnologyItem: Identifiable {
  let flag: DetectedTechnologies
  let name: String
  let symbolName: String
  var id: UInt64 { flag.rawValue }
}

extension DetectedTechnologies {

  static let frameworkFlags: [DetectedTechnologies] = [
    .appkit, .uikit, .swiftui, .webkit, .carbon, .automator,
    .electron, .catalyst, .qt, .wxWidgets, .cef, .flutter,
    .tauri, .reactNative, .capacitor, .platypus, .iOSOnMac,
  ]

  static let languageFlags: [DetectedTechnologies] = [
    .objc, .swift, .cplusplus, .python, .java, .applescript,
    .rust, .javascript,
  ]

  static let runtimeFlags: [DetectedTechnologies] = [
    .unity, .godot, .unreal, .dotnet, .avalonia, .mono,
  ]

  /// Returns display names for technologies in this set that match the given flags.
  func names(in flags: [DetectedTechnologies]) -> [String] {
    flags.compactMap { flag in
      self.contains(flag) ? flag.displayName : nil
    }
  }

  /// Returns TechnologyItem values for technologies in this set that match the given flags.
  func items(in flags: [DetectedTechnologies]) -> [TechnologyItem] {
    flags.compactMap { flag in
      guard self.contains(flag),
            let name = flag.displayName else { return nil }
      return TechnologyItem(flag: flag, name: name, symbolName: flag.symbolName)
    }
  }
}
