//
//  OTool.swift
//  AppXray
//

import Foundation

enum OToolError: Swift.Error {
  case xCodeMissing
  case objdumpMissing
  case invocationFailed(status: Int)
}

/// Path to the bundled llvm-objdump binary. Add it via a Copy Files build
/// phase targeting "Executables" and ensure it is signed.
fileprivate let embeddedObjdump : URL = {
  return Bundle.main.bundleURL
    .appendingPathComponent("Contents")
    .appendingPathComponent("MacOS")
    .appendingPathComponent("llvm-objdump")
}()

func otool(_ url: URL) throws -> [ String ] {
  // xcrun is blocked by the sandbox; Xcode's objdump works on macOS but not
  // under Catalyst. Prefer the bundled, signed copy; fall back to a *verified*
  // Xcode install. If neither exists, fail cleanly -- detection still works
  // from the bundle structure and Info.plist.
  let fm = FileManager.default

  let objdump : String
  if fm.isExecutableFile(atPath: embeddedObjdump.path) {
    objdump = embeddedObjdump.path
  }
  else {
    let xcodeObjdump =
      "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/objdump"
    guard fm.isExecutableFile(atPath: xcodeObjdump) else {
      throw OToolError.objdumpMissing
    }
    objdump = xcodeObjdump
  }

  var dependencies = Set<String>()
  dependencies.reserveCapacity(32)
  var scanned = Set<String>() // resolved file paths already objdumped
  try run(objdump: objdump, against: url, maxNesting: 3,
          into: &dependencies, scanned: &scanned)
  return dependencies.sorted()
}

private func run(objdump: String, against url: URL,
                 nesting: Int = 1, maxNesting: Int = 4,
                 into result: inout Set<String>,
                 scanned: inout Set<String>) throws
{
  guard nesting <= maxNesting else { return }

  // Mark this file as scanned so a shared dependency reached via two different
  // parents is not objdumped (and re-walked) more than once.
  scanned.insert(url.resolvingSymlinksInPath().path)

  let directDeps = try run(objdump: objdump, against: url)
  result.formUnion(directDeps)
  guard nesting + 1 <= maxNesting else { return }

  let baseURL = url
    .deletingLastPathComponent() // Slack
    .deletingLastPathComponent() // MacOS

  for dep in directDeps {
    let dependencyURL : URL
    
    func checkRelname<S: StringProtocol>(_ relname: S) -> URL? {
      let fw      = baseURL.appendingPathComponent("Frameworks")
      let fwDep   = fw.appendingPathComponent(String(relname))
      guard FileManager.default.fileExists(atPath: fwDep.path) else {
        print("did not find @ dep:",
              "\n  dep: ", dep,
              "\n  in:  ", url.path,
              "\n  base:", baseURL.path)
        return nil
      }
      return fwDep
    }
    
    // Resolve loader-relative paths to the bundle's Frameworks directory
    if dep.hasPrefix("@rpath/") {
      guard let url = checkRelname(dep.dropFirst(7)) else { continue }
      dependencyURL = url
    }
    else if dep.hasPrefix("@executable_path/../Frameworks/") {
      guard let url = checkRelname(dep.dropFirst(31)) else { continue }
      dependencyURL = url
    }
    else if dep.hasPrefix("@loader_path/../Frameworks/") {
      guard let url = checkRelname(dep.dropFirst(27)) else { continue }
      dependencyURL = url
    }
    else if dep.hasPrefix("@") {
      // e.g. @rpath/libswiftos.dylib
      print("unprocessed dependency @:", dep)
      continue
    }
    else {
      dependencyURL = URL(fileURLWithPath: dep, relativeTo: url)
    }
    
    // Skip subtrees already walked via another parent (live dedup).
    guard !scanned.contains(dependencyURL.resolvingSymlinksInPath().path) else {
      continue
    }

    // System libraries (/usr/lib, /System/Library) have lived only in the
    // dyld shared cache since macOS 11 -- there is no file to objdump, so
    // don't pay a doomed process spawn. Their names are already in `result`.
    guard FileManager.default.fileExists(atPath: dependencyURL.path) else {
      continue
    }

    do {
      try run(objdump: objdump, against: dependencyURL,
              nesting: nesting + 1, maxNesting: maxNesting,
              into: &result, scanned: &scanned)
    }
    catch {
      print("ERROR: ignoring nested error:", error)
    }
  }
}

private func run(objdump: String, against url: URL) throws -> [ String ] {
  let result = Process.launch(at: objdump,
                              with: [ "--macho", "--dylibs-used", url.path ],
                              using: .none /* no shell */)
  guard result.status == 0 else {
    // status is 4 on signing errors (illegal instruction)
    // status is 127 for bash errors
    print("ERROR: objdump result:", result,
          "\n  path:", objdump,
          "\n  error:\n", result.stderr)
    throw OToolError.invocationFailed(status: result.status)
  }
  
  // Parse objdump output: each dependency line is indented and ends with a
  // parenthesized "(compatibility version ...)" suffix. Strip that suffix
  // precisely -- a path may itself contain '(' so lastIndex(of: "(") is wrong.
  return result.stdout
    .split(separator: "\n", omittingEmptySubsequences: true)
    .lazy
    .filter { $0.hasPrefix(" ") || $0.hasPrefix("\t") }
    .map { ( s : Substring ) -> Substring in
      if let r = s.range(of: " (compatibility version") { return s[..<r.lowerBound] }
      if let r = s.range(of: " (architecture")          { return s[..<r.lowerBound] }
      return s
    }
    .map    { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }
}
