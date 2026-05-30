//
//  DetailsPopover.swift
//  AppXray
//

import SwiftUI

struct DetailsPopover: View {

  let info: ExecutableFileTechnologyInfo

  private struct BundleInfoView: View {

    let info: InfoDict

    private var title: String {
      info.displayName ?? info.name ?? info.id ?? "Unknown"
    }

    var body: some View {
      VStack {
        Text(verbatim: "Bundle: \(title)")
          .font(.callout)
          .fontWeight(.medium)
          .padding()

        VStack(alignment: .leading, spacing: 4) {
          PropertiesView(properties: [
            ( "Bundle ID", info.id ),
            ( "Name", info.name ),
            ( "Info", info.info ),
            ( "Version", info.version ),
            ( "Short Version", info.shortVersion ),
            ( "Application Category", info.applicationCategory ),
          ])
          if info.appleScriptEnabled {
            Text("AppleScript enabled")
              .font(.callout)
              .foregroundColor(.secondary)
          }
        }
      }
    }
  }

  private struct DependenciesView: View {

    let dependencies: [String]

    var body: some View {
      Group {
        if dependencies.isEmpty {
          Text("No dependencies detected.")
            .foregroundColor(.secondary)
        }
        else {
          VStack {
            Text("\(dependencies.count) dependencies")
              .font(.callout)
              .fontWeight(.medium)
              .padding()

            VStack(alignment: .leading, spacing: 2) {
              ForEach(dependencies, id: \.self) { dependency in
                Text(verbatim: dependency)
                  .font(.caption)
              }
            }
          }
        }
      }
    }
  }

  private var hasReceipt: Bool {
    guard let url = info.receiptURL else { return false }
    return FileManager.default.fileExists(atPath: url.path)
  }

  var body: some View {
    VStack {
      VStack(spacing: 8) {
        if let info = info.infoDictionary {
          BundleInfoView(info: info)
        }
        else {
          Text("No bundle information available.")
            .foregroundColor(.secondary)
        }
        if let url = info.executableURL {
          PropertyLine(name: "Executable", value: url.path)
        }

        if hasReceipt {
          Text("App Store receipt present")
            .font(.callout)
            .foregroundColor(.secondary)
        }
      }
      .padding()

      Divider()

      DependenciesView(dependencies: info.dependencies)
        .padding()
    }
  }
}
