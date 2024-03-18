//
//  LogView.swift
//  ViewFeatures/LogFeature
//
//  Created by Douglas Adams on 10/10/20.
//  Copyright © 2020-2021 Douglas Adams. All rights reserved.
//

import ComposableArchitecture
import SwiftUI

import XCGLogFeature

// ----------------------------------------------------------------------------
// MARK: - View

/// A View to display the contents of the app's log
///
struct SDRLogView: View {
  @Bindable var store: StoreOf<SDRLogCore>
      
//  @Environment(LogModel.self) var logModel

  public var body: some View {
    
    VStack {
      LogHeader(store: store)
      Divider().background(Color(.red))
      Spacer()
      LogBodyView(store: store)
      Spacer()
      Divider().background(Color(.red))
      LogFooter(store: store)
    }
    .onAppear {
      store.send(.onAppear)
    }
    .frame(minWidth: 700, maxWidth: .infinity, alignment: .leading)
    .padding(10)
  }
}

struct LogHeader: View {
  @Bindable var store: StoreOf<SDRLogCore>

//  @Environment(LogModel.self) var logModel
  
  var body: some View {
    
    HStack(spacing: 10) {
      Toggle("Show Timestamps", isOn: $store.showTimestamps )
      Spacer()
      
      Picker("Show Level", selection: $store.showLevel) {
          ForEach(LogLevel.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
        .pickerStyle(MenuPickerStyle())
      
      Spacer()
      
      Picker("Filter by", selection: $store.filterBy) {
          ForEach(LogFilter.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
        .pickerStyle(MenuPickerStyle())
      
      Image(systemName: "x.circle").foregroundColor(store.filterText == "" ? .gray : nil)
        .onTapGesture { store.filterText = "" }
      TextField("Filter text", text: $store.filterText)
      .frame(maxWidth: 300, alignment: .leading)
    }
  }
}

struct LogBodyView: View {
  @Bindable var store: StoreOf<SDRLogCore>

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView([.horizontal, .vertical]) {
        VStack(alignment: .leading) {
          ForEach( store.filteredLogLines) { message in
            Text(message.text)
              .font(.system(size: store.fontSize, weight: .regular, design: .monospaced))
              .foregroundColor(message.color)
              .textSelection(.enabled)
          }
          .onChange(of: store.goToLast) {
            if store.filteredLogLines.count > 0 {
              let id = store.goToLast ? store.filteredLogLines.last!.id : store.filteredLogLines.first!.id
              proxy.scrollTo(id, anchor: .bottomLeading)
            }
          }
          .onChange(of: store.filteredLogLines.count) {
            if store.filteredLogLines.count > 0 {
              let id = store.goToLast ? store.filteredLogLines.last!.id : store.filteredLogLines.first!.id
              proxy.scrollTo(id, anchor: .bottomLeading)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct LogFooter: View {
  @Bindable var store: StoreOf<SDRLogCore>
  
  @State private var showOpenPanel: Bool = false

  var body: some View {
    
    HStack {
      Stepper("Font Size", value: $store.fontSize, in: 8...14)
      Text(String(format: "%2.0f", store.fontSize)).frame(alignment: .leading)
      
      Spacer()
      
      HStack {
        Text("Go to \(store.goToLast ? "First" : "Last")")
        Image(systemName: store.goToLast  ? "arrow.up.square" : "arrow.down.square").font(.title)
          .onTapGesture { store.goToLast.toggle() }
      }
      .frame(width: 120, alignment: .trailing)
      Spacer()
      
      HStack(spacing: 20) {
        Button("Refresh") { store.send(.refreshButtonTapped) }
        Toggle("Auto Refresh", isOn: $store.autoRefresh)
      }
      Spacer()
      
      HStack(spacing: 20) {
        Button("Load") { store.send(.loadButtonTapped) }
        Button("Save") { store.send(.saveButtonTapped) }
      }
      
      Spacer()
      Button("Clear") { store.send(.clearButtonTapped) }
    }
    // ---------- Toolbars ----------
    .toolbar {
      ToolbarItem() {
        ToolbarRight(store: store)
      }
    }
  }
  
  private struct ToolbarRight: View {
    @Bindable var store: StoreOf<SDRLogCore>

    var body: some View {
      HStack {
        Text("Select an App")
        Picker("", selection: $store.appSelection) {
          ForEach(store.appChoices, id: \.self) {
            Text($0).tag($0)
          }
        }
        .pickerStyle(.segmented)
      }
    }
  }
}

// ----------------------------------------------------------------------------
// MARK: - Preview

#Preview {
  SDRLogView(store: Store(initialState: SDRLogCore.State()) {
    SDRLogCore()
  })
  .frame(minWidth: 975, minHeight: 400)
  .padding()
}
