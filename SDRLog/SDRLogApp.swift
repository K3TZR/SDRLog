//
//  SDRLogApp.swift
//  SDRLog
//
//  Created by Douglas Adams on 7/12/23.
//

import ComposableArchitecture
import SwiftUI

// ----------------------------------------------------------------------------
// MARK: - Main

@main
struct SDRLogApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  var appDelegate
  
  var body: some Scene {
    WindowGroup("SDRLog  (v" + Version().string + ")")  {
      SDRLogView(store: Store(initialState: SDRLogCore.State()) {
        SDRLogCore()
      })
    }
  }
}

// ----------------------------------------------------------------------------
// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // disable tab view
    NSWindow.allowsAutomaticWindowTabbing = false
  }
    
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

// ----------------------------------------------------------------------------
// MARK: - Global struct

/// Struct to hold a Semantic Version number
public struct Version {
  public var major: Int = 1
  public var minor: Int = 0
  public var build: Int = 0
  
  // can be used directly in packages
  public init(_ versionString: String = "1.0.0") {
    let components = versionString.components(separatedBy: ".")
      major = Int(components[0]) ?? 1
      minor = Int(components[1]) ?? 0
      build = Int(components[2]) ?? 0
  }
  
  // only useful for Apps & Frameworks (which have a Bundle), not Packages
  public init() {
    let versions = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String ?? "?"
    let build   = Bundle.main.infoDictionary![kCFBundleVersionKey as String] as? String ?? "?"
    self.init(versions + ".\(build)")
  }
  
  public var string: String { "\(major).\(minor).\(build)" }
}
