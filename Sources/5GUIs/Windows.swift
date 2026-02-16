//
//  Window.swift
//  5 GUIs
//
//  Copyright (c) 2020 ZeeZide GmbH. All rights reserved.
//

import SwiftUI

func makeAppWindow<V: View>(_ contentView: V) -> NSWindow {
  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
    styleMask: [
      .closable, .miniaturizable, .resizable, .titled
    ],
    backing: .buffered, defer: false
  )

  window.title = "5 GUIs"
  window.isMovableByWindowBackground = true
  window.isReleasedWhenClosed = true
  window.center()
  window.setFrameAutosaveName("5GUIs")
  window.minSize = NSMakeSize(400, 400)

  window.contentView = NSHostingView(
    rootView: contentView
      .environment(\.window, window)
  )
  window.makeFirstResponder(window.contentView)
  return window
}

func makeOpenPanel() -> NSOpenPanel {
  let panel = NSOpenPanel()
  panel.canChooseFiles          = true
  panel.canChooseDirectories    = true
  panel.canCreateDirectories    = false
  panel.showsHiddenFiles        = true
  panel.allowsMultipleSelection = true
  panel.title = "Choose an application"
  return panel
}

func makeInfoPanel<V: View>(_ contentView: V) -> NSWindow {
  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
    styleMask: [
      .closable, .titled
    ],
    backing: .buffered, defer: false
  )

  window.title = "About 5 GUIs"
  window.isMovableByWindowBackground = true
  window.center()
  window.setFrameAutosaveName("5GUIs Info")

  window.contentView = NSHostingView(
    rootView: contentView
      .environment(\.window, window)
  )
  return window
}

func makeLicenseWindow<V: View>(_ contentView: V) -> NSWindow {
  let window = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 700, height: 480),
    styleMask: [
      .closable, .titled, .resizable
    ],
    backing: .buffered, defer: false
  )
  window.minSize = NSMakeSize(700, 300)

  window.title = "Third-Party Licenses"
  window.isMovableByWindowBackground = true
  window.isReleasedWhenClosed = false
  window.center()
  window.setFrameAutosaveName("5GUIs Licenses")

  window.contentView = NSHostingView(
    rootView: contentView
      .environment(\.window, window)
  )
  return window
}
