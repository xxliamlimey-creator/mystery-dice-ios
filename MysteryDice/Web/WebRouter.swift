//
//  WebRouter.swift
//  Opens out-of-scope URLs outside the WebView and finds a presenter.
//

import UIKit
import SafariServices

enum WebRouter {

    /// Opens a URL that must not load inside the WebView.
    static func open(_ url: URL) {
        let scheme = url.scheme?.lowercased()

        // App-handled schemes go straight to the system.
        if let scheme = scheme, ["tel", "mailto", "sms", "facetime", "maps", "itms-apps"].contains(scheme) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success { presentSafari(url) }
            }
            return
        }

        switch AppConfig.externalLinkStyle {
        case .inAppBrowser:
            presentSafari(url)
        case .systemBrowser:
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    static func presentSafari(_ url: URL) {
        guard let presenter = UIApplication.shared.topViewController else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        // Avoid stacking sheets on top of an already presented controller.
        guard presenter.presentedViewController == nil else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }

        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = AppConfig.accentUIColor
        controller.dismissButtonStyle = .done
        controller.modalPresentationStyle = .fullScreen
        presenter.present(controller, animated: true)
    }

    /// Native alert for `window.alert` / `confirm` / `prompt`, and for errors we
    /// want the player to see.
    static func presentAlert(title: String?, message: String?, actions: [UIAlertAction] = []) {
        guard let presenter = UIApplication.shared.topViewController else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if actions.isEmpty {
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        } else {
            actions.forEach(alert.addAction)
        }
        presenter.present(alert, animated: true)
    }
}

extension UIApplication {

    /// Top-most view controller of the active window scene.
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = scene?.keyWindow

        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        if let navigation = top as? UINavigationController {
            return navigation.visibleViewController ?? navigation
        }
        if let tab = top as? UITabBarController {
            return tab.selectedViewController ?? tab
        }
        return top
    }
}
