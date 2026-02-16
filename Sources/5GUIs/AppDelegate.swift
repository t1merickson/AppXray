//
//  AppDelegate.swift
//  5 GUIs
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    let window = makeAppWindow(ContentView())
    window.makeKeyAndOrderFront(nil)
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  @IBAction func newDocument(_ sender: Any?) {
    let window = makeAppWindow(ContentView())
    window.makeKeyAndOrderFront(nil)
  }

  @IBAction func openDocument(_ sender: Any?) {
    let panel = makeOpenPanel()
    panel.begin { response in
      guard response == .OK else { return }

      for url in panel.urls {
        let view   = ContentView()
        let window = makeAppWindow(view)
        window.makeKeyAndOrderFront(nil)
        view.loadURL(url)
      }
    }
  }

  private lazy var infoPanel = makeInfoPanel(InfoPanel())
  private lazy var licenseWindow = makeLicenseWindow(ThirdPartyLicensesView())

  @IBAction func showInfoPanel(_ sender: Any?) {
    infoPanel.makeKeyAndOrderFront(nil)
  }

  @IBAction func showLicenses(_ sender: Any?) {
    licenseWindow.makeKeyAndOrderFront(nil)
  }
}
