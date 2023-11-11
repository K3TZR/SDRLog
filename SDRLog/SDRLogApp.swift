//
//  SDRLogApp.swift
//  SDRLog
//
//  Created by Douglas Adams on 7/12/23.
//

import SwiftUI

import LogViewer
import SettingsModel
import SharedModel

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

  @State var settings = SettingsModel.shared
  @State var logModel = LogModel.shared

  var flexFolderUrl: URL? {
    let container = FileManager().containerURL(forSecurityApplicationGroupIdentifier: SettingsModel.FlexSuite)
    return container?.appending(path: "Library/Application Support/Logs")
  }
  
  var body: some Scene {
    WindowGroup {
      if flexFolderUrl == nil {
        Text("FATAL ERROR - Flex App Group folder not found")
      } else {
        LogView(domain: "net.k3tzr", appName: "Sdr6000", folderUrl: flexFolderUrl!)
          .environment(settings)
          .environment(logModel)
      }
    }
  }
}
