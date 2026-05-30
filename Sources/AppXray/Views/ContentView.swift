//
//  ContentView.swift
//  AppXray
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

  @Environment(\.window) private var window

  @StateObject private var state = WindowState()
  @State       private var isTargeted = false
  @State       private var didLoadInitial = false

  /// URL to load when the view first appears (set when a window is opened for a
  /// specific file). Passing it in at construction lets `state` stay a
  /// @StateObject that SwiftUI owns, rather than a manually-held reference.
  private let initialURL: URL?

  init(url: URL? = nil) {
    self.initialURL = url
  }

  private func openInNewWindow(_ url: URL) {
    let window = makeAppWindow(ContentView(url: url))
    window.makeKeyAndOrderFront(nil)
  }

  private func loadURLs(_ urls: [URL]) {
    urls.first.flatMap { state.loadURL($0) }
    urls.dropFirst().forEach { openInNewWindow($0) }
  }

  private func handleDrop(items: [NSItemProvider]) -> Bool {
    guard !items.isEmpty else { return false }

    items.first.flatMap { $0.loadURL { $0.flatMap { state.loadURL($0) } } }

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
    .frame(minWidth: 400, maxWidth: 600, minHeight: 400, maxHeight: .infinity)
    .animation(.default, value: state.state)

    .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted,
            perform: handleDrop)

    .onAppear {
      guard !didLoadInitial, let initialURL = initialURL else { return }
      didLoadInitial = true
      state.loadURL(initialURL)
    }
  }
}
