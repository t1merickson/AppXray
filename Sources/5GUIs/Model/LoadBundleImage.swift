//
//  LoadBundleImage.swift
//  5 GUIs
//

import class  Foundation.Bundle
import class  AppKit.NSImage
import class  AppKit.NSWorkspace
import struct SwiftUI.Image

/// Loads the app icon from the bundle using the Info.plist icon name/file.
/// Falls back to NSWorkspace's icon for the bundle path if none is found.
func loadImage(in info: InfoDict, bundle: Bundle) -> Image {
  let bundleImage : Image? = {
    // Note: `Image(name, bundle:)` is lazy.
    if let name    = info.iconName,
       let nsImage = bundle.image(forResource: name)
    {
      return Image(nsImage: nsImage)
    }
    guard let iconFile = info.iconFile else { // e.g. helper apps
      print("WARN: No image set"); return nil
    }
    if let nsImage = bundle.image(forResource: iconFile) { // TimeMachine
      return Image(nsImage: nsImage)
    }
    
    guard let path = bundle.path(forResource: iconFile, ofType: nil) else {
      print("ERROR: did not find:", iconFile); return nil
    }
    guard let nsImage = NSImage(contentsOfFile: path) else {
      print("ERROR: could not load image:", path); return nil
    }
    return Image(nsImage: nsImage)
  }()
  
  if let image = bundleImage {
    return image
  }
  
  // Fallback: NSWorkspace icon (lower resolution)
  return Image(nsImage: NSWorkspace.shared.icon(forFile: bundle.bundlePath))
}

