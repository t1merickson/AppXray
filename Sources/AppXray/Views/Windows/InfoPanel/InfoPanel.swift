//
//  InfoPanel.swift
//  AppXray
//

import SwiftUI

struct InfoPanel: View {

  var body: some View {
    VStack(spacing: 16) {
      Image(nsImage: appIcon)
        .resizable()
        .frame(width: 64, height: 64)
        .padding(.top)

      VStack(spacing: 4) {
        Text("AppXray")
          .font(.title2)
          .fontWeight(.semibold)

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
          Text("Version \(version)")
            .font(.callout)
            .foregroundColor(.secondary)
        }
      }

      Text(
        "Drop any macOS application to see what makes it tick. " +
        "AppXray scans the app bundle structure, linked libraries, " +
        "and binary contents to identify the 40+ frameworks, languages, " +
        "runtimes, and tools behind it."
      )
        .font(.callout)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 380)
        .fixedSize(horizontal: false, vertical: true)

      Button("Third-Party Licenses") {
        NSApp.sendAction(#selector(InfoPanelActions.showLicenses(_:)), to: nil, from: nil)
      }
      .padding(.top, 4)

      Text("Based on 5 GUIs by ZeeZide GmbH")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(24)
    .frame(width: 340)
  }
}

@objc protocol InfoPanelActions {
  func showLicenses(_ sender: Any?)
}
