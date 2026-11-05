//
//  WebViewModel.swift
//  Load state for the single WKWebView: progress, splash, failure, history.
//

import Foundation
import WebKit
import Combine

final class WebViewModel: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var progress: Double = 0
    @Published var isFirstLoad = true
    @Published var showSplash = true
    @Published var didFail = false
    @Published var canGoBack = false

    // MARK: - Internals

    private(set) weak var webView: WKWebView?
    private var observations: [NSKeyValueObservation] = []
    private var hasRequestedInitialLoad = false
    private var splashPresentedAt = Date()

    // MARK: - Wiring

    func attach(_ webView: WKWebView) {
        guard self.webView !== webView else { return }
        self.webView = webView

        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                let value = view.estimatedProgress
                DispatchQueue.main.async { self?.progress = value }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                let value = view.canGoBack
                DispatchQueue.main.async { self?.canGoBack = value }
            }
        ]
    }

    func detach() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        webView = nil
    }

    // MARK: - Commands

    /// Called once, from `WebView.makeUIView`.
    func loadInitialPageIfNeeded() {
        guard !hasRequestedInitialLoad, let webView else { return }
        hasRequestedInitialLoad = true
        splashPresentedAt = Date()
        loadStartPage(in: webView)
    }

    func reload() {
        guard let webView else { return }
        didFail = false
        if webView.url == nil {
            loadStartPage(in: webView)
        } else {
            webView.reload()
        }
    }

    func goBack() {
        guard let webView, webView.canGoBack else { return }
        webView.goBack()
    }

    /// WebKit kills its content process under memory pressure; recover silently
    /// instead of showing the player a dead white screen.
    func recoverFromWebProcessTermination() {
        guard let webView else { return }
        didFail = false
        if webView.url == nil {
            loadStartPage(in: webView)
        } else {
            webView.reload()
        }
    }

    func resumeAfterBackground() {
        guard let webView, webView.url == nil, hasRequestedInitialLoad else { return }
        didFail = false
        loadStartPage(in: webView)
    }

    // MARK: - Lifecycle callbacks from the Coordinator

    func handleStartedLoad() {
        didFail = false
    }

    func handleFinishedLoad() {
        isFirstLoad = false
        hideSplashAfterMinimumDuration()
    }

    func handleFailure(_ error: Error) {
        guard !Self.isCancellation(error) else { return }
        isFirstLoad = false
        didFail = true
        showSplash = false
    }

    // MARK: - Helpers

    private func loadStartPage(in webView: WKWebView) {
        var request = URLRequest(url: AppConfig.startURL)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadRevalidatingCacheData
        webView.load(request)
    }

    private func hideSplashAfterMinimumDuration() {
        guard showSplash else { return }
        let elapsed = Date().timeIntervalSince(splashPresentedAt)
        let remaining = max(0, AppConfig.minimumSplashDuration - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
            self?.showSplash = false
        }
    }

    /// -999 (user cancelled) and WebKit's 102 (frame load interrupted) are not errors.
    private static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return true
        }
        if nsError.domain == "WebKitErrorDomain", nsError.code == 102 {
            return true
        }
        return false
    }
}
