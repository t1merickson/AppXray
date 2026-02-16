//
//  URLItems.swift
//  5 GUIs
//

import struct Foundation.Data
import struct Foundation.URL
import class  SwiftUI.NSItemProvider
import class  AppKit.RunLoop
import UniformTypeIdentifiers

extension NSItemProvider {

  func loadURL(forTypeIdentifier id: String = UTType.fileURL.identifier,
               yield: @escaping ( URL? ) -> Void)
  {
    loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
      urlData, error in

      guard let urlData = urlData as? Data else {
        print("failed to load URL data:", error as Any)
        return yield(nil)
      }

      guard let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
        print("failed to decode URL data:", urlData)
        return yield(nil)
      }

      RunLoop.main.perform {
        yield(url)
      }
    }
  }
}
