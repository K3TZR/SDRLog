//
//  SDRLogApp.swift
//  SDRLog
//
//  Created by Douglas Adams on 7/12/23.
//

import ComposableArchitecture
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // disable tab view
    NSWindow.allowsAutomaticWindowTabbing = false
  }
    
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

@main
struct SDRLogApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  var appDelegate
  
  var body: some Scene {
    WindowGroup {
      SDRLogView(store: Store(initialState: SDRLogCore.State()) {
        SDRLogCore()
      })
    }
  }
}
