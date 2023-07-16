//
//  SDRLogApp.swift
//  SDRLog
//
//  Created by Douglas Adams on 7/12/23.
//

import ComposableArchitecture
import SwiftUI

import LogView
import Shared

@main
struct SDRLogApp: App {
  
  var flexFolderUrl: URL? {
    let container = FileManager().containerURL(forSecurityApplicationGroupIdentifier: DefaultValues.flexSuite)
    return container?.appending(path: "Library/Application Support/Logs")
  }
  
  var body: some Scene {
    WindowGroup {
      if flexFolderUrl == nil {
        Text("FATAL ERROR - Flex App Group folder not found")
      } else {
        LogView(store: Store(initialState: LogFeature.State(domain: "net.k3tzr", appName: "Sdr6000", folderUrl: flexFolderUrl!), reducer: LogFeature()) )
      }
    }
  }
}
