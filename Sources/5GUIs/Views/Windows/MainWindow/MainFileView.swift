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

  private var subtitleText: String {
    let filename = info.fileURL.lastPathComponent
    if info.platformType != .unknown {
      return "\(filename) \u{2014} \(info.platformType.rawValue)"
    }
    return filename
  }

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
          VStack(spacing: 0) {
            appHeader
              .padding(.bottom, 20)

            if state.state == .finished {
              TechnologyResultsView(info: info)

              SummaryView(info: info)
                .padding(.top, 20)
                .padding(.horizontal)
            }
          }
          .padding(24)
        }
      }
    }
  }

  private var appHeader: some View {
    HStack(spacing: 16) {
      if let image = info.appImage {
        image
          .resizable()
          .frame(width: 64, height: 64)
          .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
          .onTapGesture { detailsVisible = true }
          .popover(isPresented: $detailsVisible, arrowEdge: .bottom) {
            ScrollView {
              DetailsPopover(info: info)
            }
            .frame(minWidth: 480, maxWidth: .infinity,
                   minHeight: 320, maxHeight: 840)
          }
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(appName)
          .font(.title2)
          .fontWeight(.semibold)
          .lineLimit(2)

        Text(subtitleText)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
  }
}

// MARK: - Technology Results

struct TechnologyResultsView: View {

  let info: ExecutableFileTechnologyInfo

  private var allTechs: DetectedTechnologies { info.allTechnologies }

  var body: some View {
    VStack(spacing: 16) {
      technologySection(
        title: "Frameworks",
        systemImage: "square.stack.3d.up",
        items: allTechs.items(in: DetectedTechnologies.frameworkFlags)
      )
      technologySection(
        title: "Languages",
        systemImage: "chevron.left.forwardslash.chevron.right",
        items: allTechs.items(in: DetectedTechnologies.languageFlags)
      )
      technologySection(
        title: "Runtimes",
        systemImage: "cpu",
        items: allTechs.items(in: DetectedTechnologies.runtimeFlags)
      )
    }
  }

  @ViewBuilder
  private func technologySection(
    title: String,
    systemImage: String,
    items: [TechnologyItem]
  ) -> some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 4) {
          Image(systemName: systemImage)
          Text(title)
        }
        .font(.subheadline.weight(.medium))
        .foregroundColor(.secondary)

        VStack(spacing: 0) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            TechnologyRow(item: item)
            if index < items.count - 1 {
              Divider()
                .padding(.leading, 36)
            }
          }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
      }
    }
  }
}

// MARK: - Technology Row

struct TechnologyRow: View {

  let item: TechnologyItem

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: item.symbolName)
        .frame(width: 20, height: 20)
        .foregroundColor(.accentColor)

      Text(item.name)
        .font(.body)

      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
  }
}
