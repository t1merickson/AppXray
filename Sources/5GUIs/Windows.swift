//
//  Windows.swift
//  5 GUIs
//

import SwiftUI

func makeAppWindow<V: View>(_ contentView: V) -> NSWindow {
  let minW: CGFloat = 400
  let maxW: CGFloat = 600
  let minH: CGFloat = 400
  let maxH: CGFloat = 1200

  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
    styleMask: [
      .closable, .miniaturizable, .resizable, .titled
    ],
    backing: .buffered, defer: false
  )

  window.minSize = NSMakeSize(minW, minH)
  window.maxSize = NSMakeSize(maxW, maxH)
  window.title = "5 GUIs"
  window.isMovableByWindowBackground = true
  window.isReleasedWhenClosed = true
  window.center()
  window.setFrameAutosaveName("5GUIs")

  // Clamp restored frame to current constraints
  var frame = window.frame
  frame.size.width  = min(max(frame.size.width, minW), maxW)
  frame.size.height = min(max(frame.size.height, minH), maxH)
  window.setFrame(frame, display: false)

  window.contentView = NSHostingView(
    rootView: contentView
      .environment(\.window, window)
  )
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
    contentRect: NSRect(x: 0, y: 0, width: 340, height: 0),
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
