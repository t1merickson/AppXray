//
//  InfoDict.swift
//  5 GUIs
//

/// Parsed contents of an application bundle's Info.plist.
struct InfoDict: Equatable {

  let id                   : String? // com.apple.Safari
  let name                 : String? // Safari
  let displayName          : String? // Safari
  let info                 : String?
  let version              : String?
  let shortVersion         : String? // 14.0
  let applicationCategory  : String?
  let supportedPlatforms   : [ String ] // MacOSX
  let minimumSystemVersion : String?

  // Whether the app supports AppleScript (NSAppleScriptEnabled), not whether it is one.
  let appleScriptEnabled   : Bool

  let isAutomatorApplet    : Bool
  let requiresCarbon       : Bool

  /// Whether the JavaX key exists (indicates a bundled JVM app, e.g. JD-GUI).
  /// The plist value is a dict containing MainClass, JVMVersion, ClassPath, etc.
  let JavaX                : Bool

  let iconName   : String? // AppIcon
  let iconFile   : String? // AppIcon

  let executable : String? // Safari

  // Extended detection keys
  let electronAsarIntegrity : Bool     // ElectronAsarIntegrity dict exists
  let electronTeamID        : String?  // ElectronTeamID
  let platformName          : String?  // DTPlatformName (e.g. "iphoneos", "macosx")
  let deviceFamily          : [Int]    // UIDeviceFamily (1 = iPhone, 2 = iPad)
  let minimumOSVersion      : String?  // MinimumOSVersion (iOS-style, not LSMinimumSystemVersion)

  init(_ dictionary: [ String : Any ]) {
    func S(_ key: String) -> String? {
      guard let s = dictionary[key] as? String else { return nil }
      return s.isEmpty ? nil : s
    }
    func B(_ key: String) -> Bool {
      guard let v = dictionary[key] else { return false }
      if let b = v as? Bool { return b }
      if let i = v as? Int  { return i != 0 }
      if let s = (v as? String)?.lowercased() {
        return (s == "no" || s == "false") ? false : !s.isEmpty
      }
      return false
    }

    id                   = S("CFBundleIdentifier")
    name                 = S("CFBundleName")
    info                 = S("CFBundleGetInfoString")
    displayName          = S("CFBundleDisplayName")
    version              = S("CFBundleVersion")
    shortVersion         = S("CFBundleShortVersionString")
    minimumSystemVersion = S("LSMinimumSystemVersion")
    applicationCategory  = S("LSApplicationCategoryType")

    iconName             = S("CFBundleIconName")
    iconFile             = S("CFBundleIconFile")

    executable           = S("CFBundleExecutable")

    appleScriptEnabled   = B("NSAppleScriptEnabled")
    isAutomatorApplet    = B("AMIsApplet")
    requiresCarbon       = B("LSRequiresCarbon")

    supportedPlatforms = dictionary["CFBundleSupportedPlatforms"] as? [ String ]
                      ?? []

    JavaX = dictionary["JavaX"] != nil

    // Extended keys
    electronAsarIntegrity = dictionary["ElectronAsarIntegrity"] != nil
    electronTeamID        = S("ElectronTeamID")
    platformName          = S("DTPlatformName")
    minimumOSVersion      = S("MinimumOSVersion")
    deviceFamily          = dictionary["UIDeviceFamily"] as? [Int] ?? []
  }
}
