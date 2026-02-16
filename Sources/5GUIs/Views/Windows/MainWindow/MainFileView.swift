//
//  MainFileView.swift
//  5 GUIs
//
//  Created by Helge Hess on 28.09.20.
//

import SwiftUI

struct MainFileView: View {

  @ObservedObject var state: BundleFeatureDetectionOperation

  @State private var detailsVisible = false

  private var appName: String { state.info.appName }
  private var info: ExecutableFileTechnologyInfo { state.info }

  var body: some View {
    Group {
      if state.state == .processing {
        VStack(spacing: 16) {
          Spacer()
          ProgressView()
            .controlSize(.large)
          Text("Analyzing...")
            .font(.body)
            .foregroundColor(.secondary)
          Spacer()
        }
      }
      else {
        ScrollView {
          VStack(spacing: 16) {
            appHeader

            if state.state == .finished {
              TechnologyResultsView(info: info)

              SummaryView(info: info)
                .padding(.horizontal)
            }
          }
          .padding()
        }
      }
    }
  }

  private var appHeader: some View {
    VStack(spacing: 8) {
      if let image = info.appImage {
        image
          .resizable()
          .frame(width: 96, height: 96)
          .onTapGesture { detailsVisible = true }
          .popover(isPresented: $detailsVisible, arrowEdge: .bottom) {
            ScrollView {
              DetailsPopover(info: info)
            }
            .frame(minWidth: 480, maxWidth: .infinity,
                   minHeight: 320, maxHeight: 840)
          }
      }

      Text(appName)
        .font(.title)
        .fontWeight(.medium)

      if info.platformType != .unknown {
        Text("Platform: \(info.platformType.rawValue)")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .padding(.bottom, 8)
  }
}

// MARK: - Technology Results

struct TechnologyResultsView: View {

  let info: ExecutableFileTechnologyInfo

  private var allTechs: DetectedTechnologies { info.allTechnologies }

  var body: some View {
    VStack(spacing: 12) {
      technologyGroup(
        title: "Frameworks",
        names: allTechs.names(in: DetectedTechnologies.frameworkFlags)
      )
      technologyGroup(
        title: "Languages",
        names: allTechs.names(in: DetectedTechnologies.languageFlags)
      )
      technologyGroup(
        title: "Runtimes",
        names: allTechs.names(in: DetectedTechnologies.runtimeFlags)
      )
    }
  }

  @ViewBuilder
  private func technologyGroup(title: String, names: [String]) -> some View {
    if !names.isEmpty {
      GroupBox(label: Text(title).font(.headline)) {
        HStack {
          Text(names.joined(separator: ", "))
            .font(.body)
          Spacer()
        }
        .padding(.top, 2)
      }
    }
  }
}
