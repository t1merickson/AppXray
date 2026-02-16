//
//  SorryNotAnExecutableView.swift
//  5 GUIs
//
//  Copyright (c) 2020 ZeeZide GmbH. All rights reserved.
//

import SwiftUI

struct SorryNotAnExecutableView: View {

  let url: URL

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable()
        .frame(width: 64, height: 64)

      Text(verbatim: url.lastPathComponent)
        .font(.title3)
        .fontWeight(.medium)

      Text("Not an application")
        .font(.title2)

      Text("This file doesn't appear to be a macOS application. Try dropping a .app bundle.")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)

      Spacer()
    }
    .padding(32)
  }
}
