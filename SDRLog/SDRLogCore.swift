//
//  SDRLogCore.swift
//  SDRLog
//
//  Created by Douglas Adams on 3/16/24.
//

import ComposableArchitecture
import Foundation
import SwiftUI

import XCGLogFeature

enum CancelID { case response }

@Reducer
public struct SDRLogCore {
  
  public init() {}
  
  @Dependency(\.continuousClock) var clock
  
  // ----------------------------------------------------------------------------
  // MARK: - State
  
  @ObservableState
  public struct State {
    
    let AppDefaults = UserDefaults.standard
    
    // persistent
    var appSelection = "SDR6000"        {didSet { AppDefaults.set(appSelection, forKey: "appSelection")}}
    var autoRefresh = false             {didSet { AppDefaults.set(autoRefresh, forKey: "autoRefresh")}}
    var filterBy: LogFilter = .none     {didSet { AppDefaults.set(filterBy.rawValue, forKey: "filterBy")}}
    var filterText: String = ""         {didSet { AppDefaults.set(filterText, forKey: "filterText")}}
    var fontSize: Double = 12           {didSet { AppDefaults.set(fontSize, forKey: "fontSize")}}
    var goToLast = false                {didSet { AppDefaults.set(goToLast, forKey: "goToLast")}}
    var showLevel: LogLevel = .debug    {didSet { AppDefaults.set(showLevel.rawValue, forKey: "showLevel")}}
    var showTimestamps = true           {didSet { AppDefaults.set(showTimestamps, forKey: "showTimestamps")}}
    
    // non-persistent
    var initialized = false
    var selection: String? = nil
    var folderUrl: URL!
    var fileUrl: URL!
    var logLines = [LogLine]()
    var filteredLogLines = [LogLine]()
    var autoRefreshTask: Task<(), Never>?
    
    let appChoices = ["SDR6000", "SDRApi", "SDRDax"]
    
    @Presents var showAlert: AlertState<Action.Alert>?
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Actions
  
  public enum Action: BindableAction {
    case binding(BindingAction<State>)
    
    case onAppear
    
    case clearButtonTapped
    case loadButtonTapped
    case refreshButtonTapped
    case saveButtonTapped
    
    // secondary actions
    case showAlert(Alert,String)
    
    // navigation actions
    case alert(PresentationAction<Alert>)
    
    // alert sub-actions
    public enum Alert : String {
      case unknownError = "Unknown error logged"
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Reducer
  
  public var body: some ReducerOf<Self> {
    BindingReducer()
    
    Reduce { state, action in
      switch action {
        
        // ----------------------------------------------------------------------------
        // MARK: - Root Actions
        
      case .onAppear:
        // perform initialization
        return initState(&state)
        
      case .clearButtonTapped:
        state.filteredLogLines.removeAll()
        return .none
        
      case .loadButtonTapped:
        if let loadUrl = showOpenPanel(state.folderUrl, state.appSelection) {
          state.logLines.removeAll()
          state.fileUrl = loadUrl
          readLogFile(&state)
        }
        return .none
        
      case .refreshButtonTapped:
        state.logLines.removeAll()
        readLogFile(&state)
        return .none
        
      case .saveButtonTapped:
        if let saveUrl = showSavePanel() {
          let textArray = state.filteredLogLines.map { $0.text }
          let fileTextArray = textArray.joined(separator: "\n")
          try? fileTextArray.write(to: saveUrl, atomically: true, encoding: .utf8)
        }
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Root Binding Actions
        
      case .binding(\.appSelection):
        state.fileUrl = state.folderUrl.appending(path: state.appSelection + ".log")
        state.logLines.removeAll()
        readLogFile(&state)
        return .none
        
      case .binding(\.autoRefresh):
        if state.autoRefresh {
          return .run { send in
            await withTaskCancellation(id: CancelID.response, cancelInFlight: true) {
              for await _ in clock.timer(interval: .seconds(1)) {
                await send(.refreshButtonTapped)
              }
            }
          }
          
        }
        else {
          return Effect.cancel(id: CancelID.response)
        }
        
      case .binding(\.filterText):
        filterLog(&state)
        return .none
        
      case .binding(\.filterBy):
        filterLog(&state)
        return .none
        
      case .binding(\.showLevel):
        filterLog(&state)
        return .none
        
      case .binding(\.showTimestamps):
        filterLog(&state)
        return .none
        
      case .binding(_):
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - View Presentation
        
      case let .showAlert(alertType, message):
        state.showAlert = AlertState(title: TextState(alertType.rawValue), message: TextState(message))
        return .none
        
        // ----------------------------------------------------------------------------
        // MARK: - Alert Actions
        
      case .alert(_):
        return .none
      }
    }
    // ----------------------------------------------------------------------------
    // MARK: - Sheet / Alert reducer integration
    
    .ifLet(\.$showAlert, action: /Action.alert)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization effect methods
  
  private func initState(_ state: inout State) -> Effect<SDRLogCore.Action> {
    if state.initialized == false {
      
      // load from User Defaults (use default value if not in User Defaults)
      state.appSelection = UserDefaults.standard.string(forKey: "appSelection") ?? "SDR6000"
      state.autoRefresh = UserDefaults.standard.bool(forKey: "autoRefresh")
      state.filterBy = LogFilter(rawValue: UserDefaults.standard.string(forKey: "filterBy") ?? "none") ?? .none
      state.filterText = UserDefaults.standard.string(forKey: "filterText") ?? ""
      state.fontSize = UserDefaults.standard.double(forKey: "fontSize") == 0 ? 12 : UserDefaults.standard.double(forKey: "fontSize")
      state.goToLast = UserDefaults.standard.bool(forKey: "goToLast")
      state.showLevel = LogLevel(rawValue: UserDefaults.standard.string(forKey: "showLevel") ?? "debug") ?? .debug
      state.showTimestamps = UserDefaults.standard.bool(forKey: "showTimestamps")
      
      
      if let container = FileManager().containerURL(forSecurityApplicationGroupIdentifier: "group.net.k3tzr.flexapps") {
        state.folderUrl = container.appending(path: "Library/Application Support/Logs")
        state.fileUrl = state.folderUrl.appending(path: state.appSelection + ".log")
      } else {
        fatalError("FATAL ERROR: Flex App Group folder not found")
      }
      readLogFile(&state)
      filterLog(&state)
      
      // mark as initialized
      state.initialized = true
    }
    return .none
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Helper methods
  
  private func readLogFile(_ state: inout State) {
    /// Determine the color to assign to a Log entry
    /// - Parameter text:     the entry
    /// - Returns:            a Color
    func logLineColor(_ text: String) -> Color {
      if text.contains("[Debug]") { return .gray }
      else if text.contains("[Info]") { return .primary }
      else if text.contains("[Warning]") { return .orange }
      else if text.contains("[Error]") { return .red }
      else { return .primary }
    }
    
    do {
      // get the contents of the file
      let logString = try String(contentsOf: state.fileUrl, encoding: .ascii)
      // parse it into lines
      let entries = logString.components(separatedBy: "\n").dropLast()
      for entry in entries {
        state.logLines.append(LogLine(text: entry, color: logLineColor(entry)))
      }
      filterLog(&state)
      
    } catch {
      fatalError("Unable to read Log file")
    }
  }
  
  /// Filter an array of Log entries
  private func filterLog(_ state: inout State) {
    // filter the log entries
    switch state.showLevel {
    case .debug:     state.filteredLogLines = state.logLines
    case .info:      state.filteredLogLines = state.logLines.filter { $0.text.contains(" [Error] ") || $0.text.contains(" [Warning] ") || $0.text.contains(" [Info] ") }
    case .warning:   state.filteredLogLines = state.logLines.filter { $0.text.contains(" [Error] ") || $0.text.contains(" [Warning] ") }
    case .error:     state.filteredLogLines = state.logLines.filter { $0.text.contains(" [Error] ") }
    }
    
    switch state.filterBy {
    case .prefix:       state.filteredLogLines = state.filteredLogLines.filter { $0.text.contains(" > " + state.filterText) }
    case .includes:     state.filteredLogLines = state.filteredLogLines.filter { $0.text.contains(state.filterText) }
    case .excludes:     state.filteredLogLines = state.filteredLogLines.filter { !$0.text.contains(state.filterText) }
    case .none:         break
    }
    
    if !state.showTimestamps {
      for (i, line) in state.filteredLogLines.enumerated() {
        state.filteredLogLines[i].text = String(line.text.suffix(from: line.text.firstIndex(of: "[") ?? line.text.startIndex))
      }
    }
  }
  
  /// Display a SavePanel
  /// - Returns:       the URL of the selected file or nil
  private func showSavePanel() -> URL? {
    let savePanel = NSSavePanel()
    savePanel.directoryURL = FileManager().urls(for: .desktopDirectory, in: .userDomainMask).first
    savePanel.allowedContentTypes = [.text]
    savePanel.nameFieldStringValue = "Saved.log"
    savePanel.canCreateDirectories = true
    savePanel.isExtensionHidden = false
    savePanel.allowsOtherFileTypes = false
    savePanel.title = "Save the Log"
    
    let response = savePanel.runModal()
    return response == .OK ? savePanel.url : nil
  }
  
  /// Display an OpenPanel
  /// - Returns:        the URL of the selected file or nil
  private func showOpenPanel(_ logFolderUrl: URL, _ appName: String) -> URL? {
    let delegate = panelDelegate(appName)
    let openPanel = NSOpenPanel()
    openPanel.delegate = delegate
    openPanel.directoryURL = logFolderUrl
    openPanel.allowedContentTypes = [.text]
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.canChooseFiles = true
    openPanel.title = "Open an existing Log"
    let response = openPanel.runModal()
    return response == .OK ? openPanel.url : nil
  }
}

class panelDelegate: NSObject, NSOpenSavePanelDelegate {
  var appName: String
  
  init(_ appName: String) {
    self.appName = appName.uppercased()
    super.init()
  }
  
  func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
    let components = url.lastPathComponent.components(separatedBy: ".")
    return components[0].uppercased().contains(appName)
  }
}

// ----------------------------------------------------------------------------
// MARK: - Extensions

extension UserDefaults {
  /// Read a user default entry and decode it into a struct
  /// - Parameters:
  ///    - key:         the name of the user default
  /// - Returns:        a struct (or nil)
  public class func getStructFromSettings<T: Decodable>(_ key: String, defaults: UserDefaults) -> T? {
    if let data = defaults.object(forKey: key) as? Data {
      let decoder = JSONDecoder()
      if let value = try? decoder.decode(T.self, from: data) {
        return value
      } else {
        return nil
      }
    }
    return nil
  }
  
  /// Encode a struct and write it to a user default
  /// - Parameters:
  ///    - key:        the name of the user default
  ///    - value:      a struct  to be encoded (or nil)
  public class func saveStructToSettings<T: Encodable>(_ key: String, _ value: T?, defaults: UserDefaults) {
    if value == nil {
      defaults.removeObject(forKey: key)
    } else {
      let encoder = JSONEncoder()
      if let encoded = try? encoder.encode(value) {
        defaults.set(encoded, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

}
