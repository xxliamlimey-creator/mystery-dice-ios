//
//  AppConfig.swift
//  Every knob you are likely to change lives here.
//

import SwiftUI
import UIKit

enum AppConfig {

    // MARK: - The site

    /// The page the app opens on launch.
    static let startURL = URL(string: "https://mysterydice.ai.studio/")!

    /// Hosts that stay inside the WebView. Any other http(s) link opens in a
    /// browser instead, so players never get trapped in a page with no back button.
    static let trustedHosts: Set<String> = [
        "mysterydice.ai.studio"
    ]

    /// `true`  -> WebView draws under the notch / home indicator (edge-to-edge).
    /// `false` -> WebView is inset inside the safe area (nothing can be clipped).
    ///
    /// The site ships `viewport-fit=cover` but no `env(safe-area-inset-*)` CSS,
    /// so the safe default here is `false`.
    static let edgeToEdge = false

    /// How links to other sites are opened.
    enum ExternalLinkStyle {
        /// In-app Safari sheet. Stays inside the app, shares cookies with Safari,
        /// and is the only WebView-free context Google sign-in can run in.
        case inAppBrowser
        /// Hand the URL to the real Safari app.
        case systemBrowser
    }
    static let externalLinkStyle: ExternalLinkStyle = .inAppBrowser

    // MARK: - Look and feel (matches the site's <meta name="theme-color">)

    static let backgroundUIColor = UIColor(red: 0.043, green: 0.059, blue: 0.098, alpha: 1) // #0B0F19
    static let background = Color(uiColor: backgroundUIColor)

    static let accentUIColor = UIColor(red: 0.961, green: 0.620, blue: 0.043, alpha: 1) // #F59E0B
    static let accent = Color(uiColor: accentUIColor)

    /// Shown on the native splash screen.
    static let displayName = "Mystery Dice"

    // MARK: - Behaviour

    /// Rubber-band scrolling while the page is shorter than the screen.
    /// Off by default: it causes accidental reloads in a full-screen game.
    static let bounces = false

    /// Edge swipe / two-finger swipe back and forward history.
    static let backForwardGestures = true

    /// Minimum time the splash logo stays up, so fast loads do not flash.
    static let minimumSplashDuration: TimeInterval = 0.9

    // MARK: - Helpers

    /// Decides whether a URL may load inside the WebView.
    static func canOpenInside(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host?.lowercased() else { return false }

        for trusted in trustedHosts {
            if host == trusted || host.hasSuffix("." + trusted) {
                return true
            }
        }
        return false
    }
}
