//
//  InfoPanel.swift
//  5 GUIs
//
//  Copyright (c) 2020 ZeeZide GmbH. All rights reserved.
//

import SwiftUI

fileprivate let licenseWindow =
  makeLicenseWindow(ThirdPartyLicensesView())

struct InfoPanel: View {

  var body: some View {
    VStack(spacing: 16) {
      Image(nsImage: appIcon)
        .resizable()
        .frame(width: 64, height: 64)
        .padding(.top)

      Text("5 GUIs")
        .font(.title)
        .fontWeight(.medium)

      Text(
        "Analyzes macOS applications to detect their underlying technologies. " +
        "Scans app bundles, checks linked libraries with LLVM objdump, and " +
        "identifies frameworks, languages, and runtimes including Electron, " +
        "SwiftUI, Qt, Flutter, Unity, and more."
      )
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 400)

      Spacer()

      Button("Third-Party Licenses") {
        licenseWindow.makeKeyAndOrderFront(nil)
      }

      Text("Based on 5 GUIs by ZeeZide GmbH")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
