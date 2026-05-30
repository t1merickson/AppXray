//
//  SorryNotAnExecutableView.swift
//  AppXray
//

import SwiftUI

struct SorryNotAnExecutableView: View {

  let url: URL

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      VStack(spacing: 16) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
          .resizable()
          .frame(width: 64, height: 64)
          .opacity(0.6)

        VStack(spacing: 6) {
          Text(verbatim: url.lastPathComponent)
            .font(.title3)
            .fontWeight(.medium)
            .lineLimit(2)

          Text("Not an application")
            .font(.body)
            .foregroundColor(.secondary)
        }

        Text("Try dropping a .app bundle from /Applications.")
          .font(.callout)
          .foregroundColor(Color(nsColor: .tertiaryLabelColor))
          .multilineTextAlignment(.center)
          .frame(maxWidth: 320)
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
