//
//  ProcessHelper.swift
//  AppXray
//

import Foundation

extension Process {
  
  public struct FancyResult {

    public let status     : Int
    public let outputData : Data
    public let errorData  : Data
    
    public var isSuccess  : Bool { return status == 0 }
    
    public var stdout : String {
      return String(data: outputData, encoding: .utf8) ?? "<binary data>"
    }
    public var stderr : String {
      return String(data: errorData, encoding: .utf8) ?? "<binary data>"
    }
    
    public func split(separator: Character) -> [ Substring ] {
      return stdout.split(separator: separator)
    }
    
  }
  
  /// Status returned when the launch path is missing/not executable.
  public static let launchFailedStatus = 127
  /// Status returned when the process exceeded its timeout and was killed.
  public static let timedOutStatus     = -1

  /// Launches a process and returns its captured output.
  ///
  /// Defaults to a direct argv exec (no shell) -- arguments are passed verbatim,
  /// so paths with spaces or shell metacharacters are safe. A non-nil `shell`
  /// opts into `<shell> -c`, with each argument individually quoted.
  ///
  /// Pipes are drained to EOF on concurrent background queues *before* waiting,
  /// so large output never deadlocks on the 64 KB pipe buffer and trailing
  /// bytes are not dropped. A hung child is terminated after `timeout`.
  static func launch(at launchPath: String, with arguments: [ String ],
                     currentDirectory: String? = nil,
                     using shell: String? = nil,
                     timeout: TimeInterval = 60)
    -> FancyResult
  {
    let process = Process()
    process.launchPath = shell ?? launchPath
    process.arguments  = shell != nil
      ? [ "-c", shellCommand(launchPath, arguments) ]
      : arguments

    if let cwd = currentDirectory, !cwd.isEmpty {
      process.currentDirectoryPath = cwd
    }

    // Validate before launching: Process.run() throws (catchable) but the
    // legacy launch() raises an uncatchable NSException for a bad path.
    let toolPath = process.launchPath ?? ""
    guard FileManager.default.isExecutableFile(atPath: toolPath) else {
      return FancyResult(status     : launchFailedStatus,
                         outputData : Data(),
                         errorData  : Data("launch path not executable: \(toolPath)".utf8))
    }

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError  = stderr

    // Read both pipes to EOF concurrently. readDataToEndOfFile blocks until the
    // write end closes (on process exit), so this avoids the classic deadlock
    // where waitUntilExit() hangs because the child is blocked writing > 64 KB.
    var outputData = Data()
    var errorData  = Data()
    let group = DispatchGroup()
    let readQ = DispatchQueue(label: "shell.read", attributes: .concurrent)
    readQ.async(group: group) {
      outputData = stdout.fileHandleForReading.readDataToEndOfFile()
    }
    readQ.async(group: group) {
      errorData = stderr.fileHandleForReading.readDataToEndOfFile()
    }

    do { try process.run() }
    catch {
      return FancyResult(status     : launchFailedStatus,
                         outputData : Data(),
                         errorData  : Data("failed to launch \(toolPath): \(error)".utf8))
    }

    // Watchdog: terminate (then SIGKILL) a process that overruns the deadline.
    var timedOut = false
    let watchdog = DispatchWorkItem {
      guard process.isRunning else { return }
      timedOut = true
      process.terminate()
      DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
      }
    }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

    process.waitUntilExit()
    watchdog.cancel()
    group.wait() // ensure both pipe reads have finished after exit

    return FancyResult(status     : timedOut ? timedOutStatus : Int(process.terminationStatus),
                       outputData : outputData,
                       errorData  : errorData )
  }

  /// Builds a `<shell> -c` command string with each argument single-quoted
  /// (internal single quotes escaped), so spaces/metacharacters are inert.
  private static func shellCommand(_ launchPath: String, _ arguments: [ String ]) -> String {
    func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    return ([ launchPath ] + arguments).map(q).joined(separator: " ")
  }
}

extension Process.FancyResult : CustomStringConvertible {
  
  public var description : String {
    
    func string(for data: Data) -> String {
      guard let s = String(data: data, encoding: .utf8) else {
        return data.description
      }
      if s.count > 72 {
        return String(s[..<s.index(s.startIndex, offsetBy: 72)]) + "..."
      }
      return s
    }
    
    if isSuccess, errorData.isEmpty { return string(for: outputData) }
    
    var ms = "<ProcessResult:"
    if status != 0 { ms += " \(status)" }
    
    ms += " \"\(string(for: outputData))\""
    if !errorData.isEmpty {
      ms += " stderr=\"\(string(for: errorData))\""
    }
    
    ms += ">"
    return ms
  }
}
