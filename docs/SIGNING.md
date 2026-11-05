# Getting Mystery Dice onto an iPhone

You have `MysteryDice-unsigned.ipa` (from GitHub Actions or
`scripts/make-ipa.sh`). iOS will not run it until it is signed — Apple requires
every app to carry a valid signature and a provisioning profile tied to a
device.

Only **you** can do this step: the signature must be created with your Apple ID
on your machine. It costs nothing.

---

## Option 1 — Sideloadly (Windows or Mac, simplest)

Free Apple ID, 5 minutes, no developer account.

1. Download **Sideloadly** → https://sideloadly.io (Windows or macOS build) and
   install it. On Windows also install iTunes (or the "Apple Devices" app) so the
   phone driver is present.
2. Install **iTunes / Apple Devices** if you don't already have it; connect the
   iPhone with a cable and tap **Trust This Computer**.
3. Drag `MysteryDice-unsigned.ipa` into Sideloadly.
4. Enter your **Apple ID** in the "Apple account" field. Sideloadly asks for an
   app-specific password if two-factor is on — generate one at
   https://account.apple.com → *Sign-In and Security → App-Specific Passwords*.
5. Click **Start**. Watch the log: it registers your device, creates a
   provisioning profile, signs and installs.
6. On the iPhone, open **Settings → General → VPN & Device Management →
   Developer App → [your Apple ID] → Trust**.
7. iOS 16 and later: turn on **Settings → Privacy & Security → Developer Mode**,
   then reboot the phone when prompted (needed to launch self-signed apps).

### Limits of a free Apple ID

| | Free Apple ID | Apple Developer Program ($99/yr) |
|---|---|---|
| App lifetime before re-sign | **7 days** | 1 year |
| Apps installed at once | 3 | unlimited (device limit 100/yr) |
| New App IDs per week | 10 | unlimited |
| TestFlight / App Store | ✗ | ✓ |

Re-sign by running Sideloadly again with the same `.ipa` (it overwrites the app;
localStorage/IndexedDB survive because the bundle id is unchanged).

---

## Option 2 — AltStore / SideStore (auto-refresh)

AltStore Classic re-signs your apps in the background over Wi-Fi before the
7-day expiry, so you don't get locked out.

1. Install **AltServer** on a PC/Mac → https://altstore.io.
2. Connect the iPhone, AltServer menu → *Install AltStore → [your device]*.
3. On the phone: *Settings → General → VPN & Device Management → Trust*.
4. Open AltStore → **My Apps → +** → pick `MysteryDice-unsigned.ipa`.
5. Leave AltServer running on the same Wi-Fi; AltStore refreshes the signature
   weekly. (SideStore is the no-PC variant of the same idea.)

---

## Option 3 — Xcode (Mac only, best for development)

```bash
open MysteryDice.xcodeproj
```

1. Target **MysteryDice → Signing & Capabilities** → tick *Automatically manage
   signing* → choose your personal team.
2. Select your iPhone as the run destination → ▶.
3. Xcode signs and installs. *Developer Mode* + certificate trust as above.

To produce an installable file: **Product → Archive → Distribute App →
Development** (`.ipa` for registered devices) or **Ad Hoc**.

Or from the terminal, signed in one shot:

```bash
DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/make-ipa.sh --signed
```

---

## Option 4 — App Store / TestFlight (paid account)

Requires the Apple Developer Program ($99/yr) and, realistically, more native
functionality than a WebView shell (see the App Store note in the README).

1. Create the app record in App Store Connect with bundle id
   `ai.studio.mysterydice` (or your own id — it must match the build).
2. Xcode → **Product → Archive → Distribute App → App Store Connect → Upload**.
3. TestFlight build appears after processing (~10–30 min), valid 90 days.
4. Submit for review when ready.

Uploads to App Store Connect require an app-specific password or an API key, and
the build must be signed with a distribution certificate.

---

## Signing inside CI (optional)

To get a **signed** `.ipa` straight out of GitHub Actions, add these repository
secrets:

| Secret | Value |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | password of that `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | `base64 -i profile.mobileprovision \| pbcopy` |
| `KEYCHAIN_PASSWORD` | any random string |
| `DEVELOPMENT_TEAM` | your 10-character team id |

Then replace the build step with an archive + export:

```yaml
- name: Import signing assets
  run: |
    echo "${{ secrets.BUILD_CERTIFICATE_BASE64 }}" | base64 -d > cert.p12
    echo "${{ secrets.BUILD_PROVISION_PROFILE_BASE64 }}" | base64 -d > profile.mobileprovision
    security create-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain
    security import cert.p12 -k build.keychain -P "${{ secrets.P12_PASSWORD }}" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    cp profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/

- name: Archive & export
  run: |
    xcodebuild -project MysteryDice.xcodeproj -scheme MysteryDice \
      -configuration Release -destination 'generic/platform=iOS' \
      -archivePath build/MysteryDice.xcarchive \
      DEVELOPMENT_TEAM=${{ secrets.DEVELOPMENT_TEAM }} \
      -allowProvisioningUpdates archive
    xcodebuild -exportArchive \
      -archivePath build/MysteryDice.xcarchive \
      -exportPath build/export \
      -exportOptionsPlist ExportOptions.plist \
      -allowProvisioningUpdates
```

`ExportOptions.plist` for a device install:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>development</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>YOURTEAMID</string>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict>
</plist>
```

---

## Common install errors

| Message | Cause / fix |
|---|---|
| `Unable to install "..."; the app is not signed` | You tried the unsigned `.ipa` directly — sign it first |
| `Unable to install — integrity could not be verified` | Certificate not trusted → *VPN & Device Management* |
| `Your device management settings do not allow...` | Screen Time / MDM restriction on the phone |
| `App ID limit reached` | Free account: 10 new App IDs/week |
| App icon appears but immediately closes | Developer Mode off (iOS 16+), or the build's deployment target is newer than the phone's iOS |
| `Failed to register bundle identifier` in Sideloadly | Another team already owns that bundle id — change it (see README) |
