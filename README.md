# Mystery Dice — iOS app (WKWebView)

A native iOS shell around **https://mysterydice.ai.studio/**. It is a real Xcode
app, not a bookmark: WKWebView does the rendering, Swift does the app bits
(launch screen, icon, status bar, external links, file uploads, offline
recovery, crash-free reloads).

| | |
|---|---|
| Bundle ID | `ai.studio.mysterydice` |
| Display name | Mystery Dice |
| Deployment target | iOS 15.0 |
| Devices | iPhone + iPad |
| Language | Swift 5 / SwiftUI + WebKit |
| Dependencies | none |

![App icon](MysteryDice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

---

## ⚠️ Read this first: where the `.ipa` comes from

An `.ipa` is a signed iOS app bundle. It can only be produced with **Apple's
toolchain (`xcodebuild`), which runs on macOS only** — there is no way to compile
Swift/UIKit on Windows. This project was assembled on Windows, so:

* ✅ the Xcode project, sources, icon, launch screen and build pipeline are complete
* ✅ the project file was validated structurally (parser + resolver, see below)
* ❌ **it has not been compiled yet** — that first build needs a Mac, or the free
  macOS runner on GitHub Actions
* ❌ a signed `.ipa` cannot be handed to you from Windows; it must be built and
  signed with *your* Apple ID

Both routes below end with a real `MysteryDice-unsigned.ipa` you install with
Sideloadly/AltStore (a 5-minute, no-Mac-needed install).

---

## Route A — GitHub Actions (no Mac required)

1. Create an empty repository and push this folder (the `.github/` workflow
   must be included):

   ```bash
   cd MysteryDice-iOS
   git init && git add . && git commit -m "Mystery Dice iOS wrapper"
   git branch -M main
   git remote add origin https://github.com/<you>/<repo>.git
   git push -u origin main
   ```

2. Open **Actions → Build IPA → Run workflow** (it also runs on every push).
3. When it finishes (~3–5 min), download the artifact **`MysteryDice-unsigned-ipa`**.
   Unzip it — you get `MysteryDice-unsigned.ipa`.
4. Install it: **[docs/SIGNING.md](docs/SIGNING.md)** (Sideloadly with a free
   Apple ID, ~5 minutes).

No Apple Developer account is needed for step 4.

## Route B — a Mac with Xcode

```bash
./scripts/make-ipa.sh              # unsigned → artifacts/MysteryDice-unsigned.ipa
./scripts/make-ipa.sh --signed     # signed, needs DEVELOPMENT_TEAM=XXXXXXXXXX
```

Or open `MysteryDice.xcodeproj`, pick your team under
*Signing & Capabilities*, choose your iPhone, and press ▶. To export an `.ipa`
from Xcode: *Product → Archive → Distribute App → Development / Ad Hoc*.

> First launch of a self-signed build on iOS 16+ requires **Developer Mode**:
> *Settings → Privacy & Security → Developer Mode → On*, then trust your
> certificate under *Settings → General → VPN & Device Management*.

---

## Configuring it

Everything you'd normally want to change lives in
[`MysteryDice/Config/AppConfig.swift`](MysteryDice/Config/AppConfig.swift):

| Setting | Default | Notes |
|---|---|---|
| `startURL` | `https://mysterydice.ai.studio/` | Page loaded on launch |
| `trustedHosts` | `mysterydice.ai.studio` | Anything else opens in a browser |
| `edgeToEdge` | `false` | `true` = draw under the notch |
| `externalLinkStyle` | `.inAppBrowser` | Or `.systemBrowser` |
| `backgroundUIColor` | `#0B0F19` | Matches the site's `theme-color` |

**Change the bundle id** in `MysteryDice.xcodeproj` (target → *General* →
*Bundle Identifier*) or in `scripts/make-ipa.sh` via `BUNDLE_ID=...`. `ai.studio.*`
is Google's AI Studio domain — use your own reverse-DNS id
(`com.yourname.mysterydice`) if you ever plan to ship to the App Store.

**Change the app name** → `CFBundleDisplayName` in
[`Info.plist`](MysteryDice/Resources/Info.plist).

**Change the icon** → replace
`Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024×1024, **no
transparency**), or regenerate from your own art:

```bash
pip install pillow
python scripts/make_icons.py path/to/your-art.png
```

---

## What the wrapper actually does

The site is a React + three.js SPA that leans on browser features a naive
wrapper breaks. Each of these is handled explicitly:

* **Persistence** — `.default()` website data store, so `localStorage`,
  IndexedDB (game progress, skins, leaderboards) and cookies survive restarts.
* **WebGL + 120 Hz** — `CADisableMinimumFrameDurationOnPhone`, fullscreen canvas
  enabled, hardware-accelerated WKWebView.
* **Audio** — inline playback, no user-gesture requirement for media.
* **`window.open` / `target="_blank"`** — same hosts reload in place; everything
  else opens in an `SFSafariViewController` sheet (also the only context where
  Google sign-in is allowed — see *Limits*).
* **External schemes** — `tel:`, `mailto:`, `sms:`, custom app links hand off to
  iOS instead of silently failing.
* **`<input type="file">`** — `UIDocumentPickerViewController` bridge.
* **`alert` / `confirm` / `prompt`** — native alert controllers.
* **Offline / DNS failure** — a native "Can't reach Mystery Dice" screen with a
  retry button, instead of a blank white page.
* **Web content process crashes** — auto-reload (iOS kills WebKit processes under
  memory pressure; without this the player sees a frozen screen).
* **Safe area** — the WebView is framed inside the notch/home-indicator area by
  default, because the site's CSS has `viewport-fit=cover` but no
  `env(safe-area-inset-*)` rules, so edge-to-edge would clip the HUD.
* **Launch experience** — dark launch screen (`#0B0F19` + logo), then an animated
  in-app splash with the real page-load progress bar, so there is no white flash.
* **No accidental refreshes** — rubber-band bounce is off; games reload by
  accident on pull-down gestures otherwise.

---

## Known limits (honest list)

1. **Google sign-in.** Google blocks OAuth inside embedded WebViews
   (`disallowed_useragent`). The site references `apis.google.com` /
   `securetoken.google.com`, so if it offers Google login inside the page it will
   fail there. The wrapper routes popups to `SFSafariViewController`, which is
   permitted — but it is a separate cookie jar, so the session may not return to
   the WebView. If login matters, ask for an email/password or token-based flow.
2. **Push notifications** are not available to a plain WebView app (needs a
   native APNs integration + `UNUserNotificationCenter`).
3. **Free-Apple-ID installs expire after 7 days** and allow 3 apps / 10 App IDs
   per week. A paid Apple Developer account ($99/yr) makes it 1 year, and enables
   TestFlight (90-day builds) and the App Store.
4. **App Store review risk.** Guideline 4.2 ("Minimum Functionality") rejects
   apps that are just a repackaged website. This wrapper adds real value
   (offline state, native upload/share, camera-free UX, launch experience), but
   if you intend to publish, add something native — Game Center leaderboards,
   local multiplayer over MultipeerConnectivity, offline dice physics, StoreKit.
5. **Not yet compiled.** If the first build surfaces a Swift error, it will be a
   one-line fix; the code sticks to stable iOS 15-era APIs on purpose.

---

## How it's put together

```
MysteryDice-iOS/
├── MysteryDice.xcodeproj/          # project (objectVersion 56, shared scheme)
├── MysteryDice/
│   ├── App/MysteryDiceApp.swift    # @main, scene phase handling
│   ├── Config/AppConfig.swift      # every knob: URL, hosts, colors, behaviour
│   ├── Web/
│   │   ├── WebView.swift           # WKWebView + navigation/UI delegates
│   │   ├── WebViewModel.swift      # progress, splash, failure, history state
│   │   └── WebRouter.swift         # SFSafariViewController + alert presenter
│   ├── UI/
│   │   ├── RootView.swift          # WebView + splash + offline overlay
│   │   └── StatusViews.swift       # splash & offline screens
│   └── Resources/
│       ├── Info.plist              # ATS, status bar, launch screen, orientation
│       └── Assets.xcassets/        # icon, accent, launch color + logo
├── .github/workflows/build-ipa.yml # macOS runner → unsigned .ipa artifact
├── scripts/
│   ├── make-ipa.sh                 # Mac: build + package (optionally sign)
│   └── make_icons.py               # regenerate icon/logo from any PNG
├── project.yml                     # optional XcodeGen spec (same project)
└── docs/SIGNING.md                 # how to get it onto an iPhone
```

The single `WKWebView` is never recreated (no navigation-stack surprises); the
SwiftUI layer only observes `progress`, `canGoBack`, `showSplash`, `didFail`.

### Validating it without a Mac

The checked-in project was verified structurally before shipping:

* `project.pbxproj` parsed with the `xcode` npm parser, then every group resolved
  to a real file → 1 target, 7 Swift sources, 1 resource, **0 dangling object
  references, 0 unlisted `.swift` files**
* every `.swift` file parsed with the tree-sitter Swift grammar → **0 syntax errors**
* `Info.plist` parsed with `plistlib` → no unknown keys, every macro and asset
  reference resolved
* asset catalog, scheme, and workflow all parse; icon is 1024×1024 with no alpha

Reproduce it:

```bash
pip install pillow
python -c "import plistlib;plistlib.load(open('MysteryDice/Resources/Info.plist','rb'))"
npm i xcode tree-sitter tree-sitter-swift   # then parse project.pbxproj / sources
```

What this cannot check is type-checking against the iOS SDK — that only happens
on the macOS build.


---

## Troubleshooting

| Symptom | Fix |
|---|---|
| White screen after the splash | Check `startURL`; the site must be reachable over HTTPS |
| Build fails: "Signing for MysteryDice requires a development team" | Select your team in Xcode, or build unsigned (`make-ipa.sh`) |
| "Unable to install — integrity could not be verified" | Re-sign with Sideloadly/AltStore; trust the cert in Settings |
| App opens then closes on launch | Deployment target must be ≤ the iPhone's iOS version |
| Login lost after reopening | Do not switch to `nonPersistent()` website data store |
| Content under the Dynamic Island | `edgeToEdge = true` and add `env(safe-area-inset-*)` padding to the site |
| Install rejected: "App ID limit reached" | Free Apple ID allows 10 App IDs/week — wait or use a paid account |
