//
//  WebView.swift
//  The WKWebView itself plus every delegate the app needs.
//

import SwiftUI
import WebKit
import UIKit
import UniformTypeIdentifiers

struct WebView: UIViewRepresentable {

    @ObservedObject var model: WebViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()               // keep IndexedDB / logins
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.applicationNameForUserAgent = "MysteryDice/1.0"

        if #available(iOS 15.4, *) {
            // Lets the three.js canvas go full screen if the page asks for it.
            configuration.preferences.isElementFullscreenEnabled = true
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = AppConfig.backgroundUIColor
        webView.scrollView.backgroundColor = AppConfig.backgroundUIColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = AppConfig.bounces
        webView.scrollView.alwaysBounceVertical = AppConfig.bounces
        webView.allowsBackForwardNavigationGestures = AppConfig.backForwardGestures
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        if #available(iOS 16.4, *) {
            webView.isInspectable = true   // Safari Web Inspector while debugging
        }

        context.coordinator.attach(webView)
        model.attach(webView)
        model.loadInitialPageIfNeeded()

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        private let model: WebViewModel
        private weak var webView: WKWebView?
        private var filePicker: FilePickerDelegate?

        init(model: WebViewModel) {
            self.model = model
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        func detach() {
            webView?.navigationDelegate = nil
            webView?.uiDelegate = nil
            webView = nil
            filePicker = nil
        }

        // MARK: Navigation policy

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // `target=_blank`, `window.open`, and popup auth: decided in
            // `createWebViewWith` so they are not handled twice.
            if navigationAction.targetFrame == nil {
                decisionHandler(.allow)
                return
            }

            // Frames inside the page (auth iframes, ads, embeds) load untouched.
            if let target = navigationAction.targetFrame, !target.isMainFrame {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""

            if scheme == "http" || scheme == "https" {
                if AppConfig.canOpenInside(url) {
                    decisionHandler(.allow)
                } else {
                    WebRouter.open(url)
                    decisionHandler(.cancel)
                }
                return
            }

            switch scheme {
            case "about", "data", "blob", "javascript":
                decisionHandler(.allow)
            default:
                // tel:, mailto:, sms:, itms-apps:, custom app schemes…
                WebRouter.open(url)
                decisionHandler(.cancel)
            }
        }

        // MARK: Navigation lifecycle

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.handleStartedLoad()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.handleFinishedLoad()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.handleFailure(error)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            model.handleFailure(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            model.recoverFromWebProcessTermination()
        }

        // MARK: New windows

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            guard let url = navigationAction.request.url else { return nil }

            if url.scheme == "about" {
                return nil   // popup written to by script; nothing to load
            }

            if AppConfig.canOpenInside(url) {
                webView.load(URLRequest(url: url))
            } else {
                WebRouter.open(url)
            }
            return nil
        }

        // MARK: JavaScript dialogs

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {

            WebRouter.presentAlert(title: AppConfig.displayName,
                                   message: message,
                                   actions: [UIAlertAction(title: "OK", style: .default) { _ in
                                       completionHandler()
                                   }])
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {

            WebRouter.presentAlert(
                title: AppConfig.displayName,
                message: message,
                actions: [
                    UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) },
                    UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) }
                ])
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {

            guard let presenter = UIApplication.shared.topViewController else {
                completionHandler(nil)
                return
            }

            let alert = UIAlertController(title: AppConfig.displayName,
                                          message: prompt,
                                          preferredStyle: .alert)
            alert.addTextField { field in
                field.text = defaultText
                field.autocapitalizationType = .none
                field.autocorrectionType = .no
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            presenter.present(alert, animated: true)
        }

        // MARK: File uploads (`<input type="file">`)

        func webView(_ webView: WKWebView,
                     runOpenPanelWith parameters: WKOpenPanelParameters,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping ([URL]?) -> Void) {

            guard let presenter = UIApplication.shared.topViewController else {
                completionHandler(nil)
                return
            }

            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item],
                                                        asCopy: true)
            picker.allowsMultipleSelection = parameters.allowsMultipleSelection

            // The picker only holds a weak delegate; keep ours alive until it closes.
            let delegate = FilePickerDelegate()
            delegate.completion = completionHandler
            self.filePicker = delegate
            picker.delegate = delegate

            presenter.present(picker, animated: true)
        }
    }

    // MARK: - Document picker

    final class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {

        var completion: (([URL]?) -> Void)?

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            completion?(urls)
            completion = nil
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion?(nil)
            completion = nil
        }
    }
}
