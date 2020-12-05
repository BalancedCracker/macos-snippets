//
//  SnipApp.swift
//  Snip
//
//  Created by Anthony Fernandez on 12/4/20.
//  Copyright © 2020 pictarine. All rights reserved.
//

import SwiftUI

@main
struct SnipApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
          SnipViewApp(viewModel: SnipViewAppViewModel())
            .environmentObject(Settings())
            .environmentObject(AppState())
            .frame(minWidth: 700,
                   idealWidth: 1000,
                   maxWidth: .infinity,
                   minHeight: 500,
                   idealHeight: 600,
                   maxHeight: .infinity)
        }
      
    }
}
