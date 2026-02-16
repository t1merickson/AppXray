//
//  ContentView.swift
//  5 GUIs
//
//  Created by Helge Hess on 28.09.20.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

  @Environment(\.window) private var window

  @State          private var isTargeted = false
  @ObservedObject private var stateObserver : WindowState
  private var state = WindowState()

  init() {
    stateObserver = state
  }

  private var url: URL? { state.url }

  func loadURL(_ url: URL) {
    window?.title = url.lastPathComponent
    state.loadURL(url)
  }

  private func openInNewWindow(_ url: URL) {
    let view   = ContentView()
    let window = makeAppWindow(view)
    window.makeKeyAndOrderFront(nil)
    view.loadURL(url)
  }

  private func loadURLs(_ urls: [URL]) {
    urls.first.flatMap(loadURL)
    urls.dropFirst().forEach { openInNewWindow($0) }
  }

  private func handleDrop(items: [NSItemProvider]) -> Bool {
    guard !items.isEmpty else { return false }

    items.first.flatMap { $0.loadURL { $0.flatMap(self.loadURL) } }

    items.dropFirst().forEach {
      $0.loadURL { $0.flatMap { openInNewWindow($0) } }
    }

    return true
  }

  private func onOpen() {
    let panel = makeOpenPanel()
    if let window = window {
      panel.beginSheetModal(for: window) { response in
        if response == .OK { self.loadURLs(panel.urls) }
      }
    }
    else {
      panel.begin { response in
        if response == .OK { self.loadURLs(panel.urls) }
      }
    }
  }

  var body: some View {
    Group {
      if isTargeted {
        PleaseDropAFileView()
      }
      else if case .notAnApp(let url) = state.state {
        SorryNotAnExecutableView(url: url)
      }
      else if let detectionState = state.detectionState {
        MainFileView(state: detectionState)
      }
      else {
        PleaseDropAFileView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.default, value: state.state)

    .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted,
            perform: handleDrop)

    .focusable()
    .onCommand(#selector(ResponderActions.openDocument(_:)), perform: onOpen)
  }
}

@objc protocol ResponderActions {
  func openDocument(_ sender: Any?)
}
