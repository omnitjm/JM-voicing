#!/usr/bin/env bash
# Local install script for JM Voicing on macOS.
# Builds from source, installs to /Applications, strips quarantine, and launches.
# Run from inside the JM-voicing project directory.

set -euo pipefail

BRANCH="claude/check-system-status-gZIae"

echo "==> Checking prerequisites..."
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "ERROR: Xcode command-line tools are not installed."
    echo "Run: xcode-select --install"
    exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "==> Installing xcodegen via Homebrew..."
    if ! command -v brew >/dev/null 2>&1; then
        echo "ERROR: Homebrew is not installed. Install from https://brew.sh first."
        exit 1
    fi
    brew install xcodegen
fi

if [ ! -f project.yml ]; then
    echo "ERROR: project.yml not found. Run this script from the JM-voicing project root."
    exit 1
fi

echo "==> Switching to branch $BRANCH..."
git fetch origin "$BRANCH" 2>/dev/null || true
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH" "origin/$BRANCH"
git pull origin "$BRANCH" --rebase 2>/dev/null || true

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building Release config..."
xcodebuild \
    -project JMVoicing.xcodeproj \
    -scheme JMVoicing \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build | tail -n 20

APP=$(find build/Build/Products/Release -maxdepth 2 -name "JMVoicing.app" -print -quit)
if [ -z "${APP:-}" ] || [ ! -d "$APP" ]; then
    echo "ERROR: Build succeeded but JMVoicing.app not found."
    exit 1
fi
echo "==> Built: $APP"

echo "==> Stopping any running JMVoicing..."
pkill -x JMVoicing 2>/dev/null || true
sleep 1

echo "==> Installing to /Applications..."
rm -rf "/Applications/JMVoicing.app" "/Applications/JMVoicing 2.app"
cp -R "$APP" "/Applications/JMVoicing.app"

echo "==> Stripping quarantine attribute..."
xattr -dr com.apple.quarantine "/Applications/JMVoicing.app" 2>/dev/null || true

echo "==> Launching JMVoicing..."
open "/Applications/JMVoicing.app"
sleep 2

if pgrep -x JMVoicing >/dev/null; then
    echo ""
    echo "===================================================="
    echo "✓ JM Voicing is running!"
    echo "===================================================="
    echo ""
    echo "Look for the microphone icon in your menu bar."
    echo ""
    echo "Next steps:"
    echo "  1. Grant Accessibility permission when macOS asks."
    echo "  2. Click the 🎤 in the menu bar → Indstillinger…"
    echo "  3. Paste your Anthropic API key (sk-ant-...)."
    echo "  4. System Settings → Keyboard → Dictation: Off."
    echo "  5. System Settings → Keyboard → Press 🌐 key to: Do Nothing."
    echo ""
    echo "Then test:"
    echo "  - Hold Fn while speaking → release → text appears at cursor."
    echo "  - Select text + ⌃⌥G → grammar-corrected."
    echo "  - Select text + ⌃⌥A → AI-command popup."
    echo ""
else
    echo ""
    echo "✗ App did not start. Check Console.app for crash logs."
    exit 1
fi
