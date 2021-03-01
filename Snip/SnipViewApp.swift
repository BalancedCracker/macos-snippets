//
//  ContentView.swift
//  Snip
//
//  Created by Anthony Fernandez on 7/29/20.
//  Copyright © 2020 pictarine. All rights reserved.
//

import SwiftUI
import Combine

struct SnipViewApp: View {
  
  @ObservedObject var snippetManager = SnippetManager.shared
  @ObservedObject var appState: AppState
  @EnvironmentObject var settings: Settings
  
  var viewModel : SnipViewAppViewModel
  
  init(appState: AppState) {
    self.appState = appState
    self.viewModel = SnipViewAppViewModel(appState: appState)
  }
  
  var body: some View {
    appNavigation
      .environmentObject(appState)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  @ViewBuilder
  var appNavigation: some View {
    GeometryReader { reader in
      ZStack {
        NavigationView {
          
          if let sidebarViewModel = viewModel.sidebarViewModel {
            Sidebar(viewModel: sidebarViewModel)
              .frame(minWidth: 300)
          }
          
          if let codeViewerViewModel = viewModel.codeViewerViewModel {
            CodeViewer(viewModel: codeViewerViewModel)
          }
          
        }
        welcomePanel
          .frame(width: reader.size.width, height: reader.size.height)
        settingPanel
          .frame(width: reader.size.width, height: reader.size.height)
        addExternalSnipPanel
          .frame(width: reader.size.width, height: reader.size.height)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .environment(\.themePrimaryColor, settings.snipAppTheme == .auto ? .primary : .primaryTheme)
      .environment(\.themeSecondaryColor, settings.snipAppTheme == .auto ? .secondary : .secondaryTheme)
      .environment(\.themeTextColor, settings.snipAppTheme == .auto ? .text : .white)
      .environment(\.themeShadowColor, settings.snipAppTheme == .auto ? .shadow : .shadowTheme)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: viewModel.openExtensionLink) {
            Image(systemName: "square.3.stack.3d.middle.fill")
          }
          .tooltip(NSLocalizedString("Extract_Stack", comment: ""))
          .onHover { inside in
            if inside {
              NSCursor.pointingHand.push()
            } else {
              NSCursor.pop()
            }
          }
        }
      }
    }
  }
  
  var settingPanel: some View {
    GeometryReader { reader in
      SettingsView(viewModel: SettingsViewModel(isVisible: self.$settings.isSettingsOpened, readerSize: reader.size))
    }
  }
  
  var welcomePanel: some View {
    GeometryReader { reader in
      WelcomeView(viewModel: WelcomeViewModel(isVisible: self.$appState.shouldShowChangelogModel, readerSize: reader.size))
    }
  }
  
  var addExternalSnipPanel: some View {
    GeometryReader { reader in
      ExternalSnippet(viewModel: ExternalSnippetViewModel(isVisible: self.snippetManager.hasExternalSnippetQueued,
                                                          readerSize: reader.size,
                                                          onTrigger: { action in
                                                            self.viewModel.trigger(action:action)
                                                            self.viewModel.resetExternalSnippetAdding()
                                                          },
                                                          onCancel: self.viewModel.resetExternalSnippetAdding),
                      externalSnipItem: self.$snippetManager.tempSnipItem)
    }
  }
}


final class SnipViewAppViewModel: ObservableObject {
  
  @Published var snippets: [SnipItem] = []
  @Published var selectionSnipItem: SnipItem?
  
  var cancellable: AnyCancellable?
  
  var sidebarViewModel: SideBarViewModel?
  var codeViewerViewModel: CodeViewerViewModel?
  
  init(appState: AppState) {
    cancellable = SnippetManager
      .shared
      .snipets
      .sink { [weak self] (snippets) in
        guard let this = self else { return }
        this.snippets = snippets
        this.selectionSnipItem = snippets.flatternSnippets.first(where: { $0.id == appState.selectedSnippetId })
      }
    
    sidebarViewModel = SideBarViewModel(snippets: $snippets.eraseToAnyPublisher(),
                                        onTrigger: trigger(action:),
                                        onSnippetSelection: { (item, filter) in self.didSelectSnipItem(item, filter: filter, appState: appState) })
    
    codeViewerViewModel = CodeViewerViewModel(snipItem: $selectionSnipItem.eraseToAnyPublisher(),
                                              onTrigger: trigger(action:),
                                              onDimiss: { self.didDeselectSnipItem(appState: appState) })
  }
  
  deinit {
    cancellable?.cancel()
  }
  
  func trigger(action: SnipItemsListAction) {
    SnippetManager.shared.trigger(action: action)
  }
  
  func resetExternalSnippetAdding() {
    SnippetManager.shared.hasExternalSnippetQueued = false
    SnippetManager.shared.tempSnipItem = ExternalSnipItem.blank()
  }
  
  func didSelectSnipItem(_ snip: SnipItem, filter: ModelFilter, appState: AppState) {
    appState.selectedSnippetId = snip.id
    appState.selectedSnippetFilter = filter
    selectionSnipItem = snip
  }
  
  func didDeselectSnipItem(appState: AppState) {
    appState.selectedSnippetId = nil
    selectionSnipItem = nil
  }
  
  func openExtensionLink() {
    guard let url = URL(string: "https://cutt.ly/whQTNO3") else { return }
    NSWorkspace.shared.open(url)
  }
}
