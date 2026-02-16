//
//  PleaseDropAFileView.swift
//  5 GUIs
//

import SwiftUI

let appIcon = Bundle.main.image(forResource: "AppIcon")!

struct PleaseDropAFileView: View {

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      VStack(spacing: 20) {
        Image(nsImage: appIcon)
          .resizable()
          .frame(width: 80, height: 80)

        VStack(spacing: 8) {
          Text("Drop an application to analyze it")
            .font(.title3)
            .fontWeight(.medium)

          Text("Detects frameworks, languages, and runtimes including Electron, SwiftUI, Qt, Flutter, Unity, and more.")
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
        }
      }
      .padding(40)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(
            Color(nsColor: .separatorColor),
            style: StrokeStyle(lineWidth: 1.5, dash: [8, 4])
          )
      )
      .padding(.horizontal, 32)

      Spacer()
    }
    .padding(24)
  }
}
