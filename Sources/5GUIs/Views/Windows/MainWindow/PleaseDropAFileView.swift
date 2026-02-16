//
//  PleaseDropAFileView.swift
//  5 GUIs
//
//  Created by Helge Hess on 28.09.20.
//

import SwiftUI

let appIcon = Bundle.main.image(forResource: "AppIcon")!

struct PleaseDropAFileView: View {

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      Image(nsImage: appIcon)
        .resizable()
        .frame(width: 96, height: 96)

      Text("Drop an application to analyze it")
        .font(.title2)
        .fontWeight(.medium)
        .multilineTextAlignment(.center)

      Text("Detects frameworks, languages, and runtimes including Electron, SwiftUI, Qt, Flutter, Unity, and more.")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 360)

      Spacer()
    }
    .padding(32)
  }
}
