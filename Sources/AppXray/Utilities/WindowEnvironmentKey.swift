//
//  WindowEnvironmentKey.swift
//  AppXray
//

import SwiftUI

extension EnvironmentValues {

  var window : NSWindow? {
    set {
      self[WindowEnvironmentKey.self] =
        WindowEnvironmentKey.WeakWindow(window: newValue)
    }
    get {
      self[WindowEnvironmentKey.self].window
    }
  }
}

struct WindowEnvironmentKey: EnvironmentKey {
  struct WeakWindow {
    weak var window : NSWindow?
  }
  public static let defaultValue = WeakWindow(window: nil)
}
