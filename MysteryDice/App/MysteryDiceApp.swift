//
//  MysteryDiceApp.swift
//  Mystery Dice — WKWebView wrapper around https://mysterydice.ai.studio/
//

import SwiftUI

@main
struct MysteryDiceApp: App {

    @StateObject private var model = WebViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        model.resumeAfterBackground()
                    }
                }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}
