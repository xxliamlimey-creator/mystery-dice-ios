#!/usr/bin/env bash
#
# Build Mystery Dice and produce an .ipa on a Mac.
#
#   ./scripts/make-ipa.sh              # unsigned .ipa (sign later with Sideloadly/AltStore)
#   ./scripts/make-ipa.sh --signed     # development-signed .ipa (needs a team + device)
#
# Environment:
#   DEVELOPMENT_TEAM   your 10-character Apple team id (required for --signed)
#   BUNDLE_ID          override the bundle id (default: ai.studio.mysterydice)
#   VERSION            marketing version (default: 1.0)
#   BUILD_NUMBER       build number (default: timestamp)
#
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="MysteryDice"
PROJECT="MysteryDice.xcodeproj"
CONFIG="Release"
BUILD_DIR="build"
OUT_DIR="artifacts"
BUNDLE_ID="${BUNDLE_ID:-ai.studio.mysterydice}"
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
SIGNED=0

for arg in "$@"; do
  case "$arg" in
    --signed) SIGNED=1 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. This script needs macOS with Xcode installed." >&2
  exit 1
fi

if [ "$SIGNED" -eq 1 ]; then
  if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
    echo "error: --signed needs DEVELOPMENT_TEAM=<your Apple team id>" >&2
    exit 1
  fi
  SIGN_ARGS=(-allowProvisioningUpdates "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" CODE_SIGN_STYLE=Automatic)
  OUT_SUFFIX="-signed"
else
  SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO "CODE_SIGN_IDENTITY=" "CODE_SIGN_ENTITLEMENTS=")
  OUT_SUFFIX="-unsigned"
fi

echo "==> Building $SCHEME ($VERSION/$BUILD_NUMBER) bundle=$BUNDLE_ID"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$BUILD_DIR" \
  "MARKETING_VERSION=$VERSION" \
  "CURRENT_PROJECT_VERSION=$BUILD_NUMBER" \
  "PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID" \
  "${SIGN_ARGS[@]}" \
  clean build

APP_PATH="$BUILD_DIR/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "error: expected app at $APP_PATH" >&2
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP_PATH" "$OUT_DIR/Payload/"

IPA_NAME="$SCHEME$OUT_SUFFIX"
( cd "$OUT_DIR" && zip -qry "$IPA_NAME.ipa" Payload )

IPA="$OUT_DIR/$IPA_NAME.ipa"
echo
echo "==> $IPA"
ls -lh "$IPA"
if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$IPA"
fi

if [ "$SIGNED" -eq 0 ]; then
  cat <<'NOTE'

This .ipa is unsigned. Install it with Sideloadly, AltStore, or Xcode —
those tools sign it with your own Apple ID. See docs/SIGNING.md.
NOTE
fi
