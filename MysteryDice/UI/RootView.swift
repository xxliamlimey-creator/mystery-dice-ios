//
//  RootView.swift
//  Composes the WebView, the native splash, and the offline screen.
//

import SwiftUI

struct RootView: View {

    @ObservedObject var model: WebViewModel

    var body: some View {
        ZStack(alignment: .top) {
            AppConfig.background.ignoresSafeArea()

            webContent

            if model.showSplash {
                SplashView(progress: model.progress)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if model.didFail && !model.showSplash {
                OfflineView(retry: model.reload)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .background(AppConfig.background)
        .animation(.easeOut(duration: 0.35), value: model.showSplash)
        .animation(.easeOut(duration: 0.20), value: model.didFail)
    }

    @ViewBuilder
    private var webContent: some View {
        if AppConfig.edgeToEdge {
            WebView(model: model)
                .ignoresSafeArea()
        } else {
            WebView(model: model)
        }
    }
}

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(model: WebViewModel())
            .preferredColorScheme(.dark)
    }
}
#endif
