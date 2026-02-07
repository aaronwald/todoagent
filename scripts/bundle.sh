#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="TodoAgent"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "Building $APP_NAME (release)..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

echo ""
echo "Built: $APP_BUNDLE"
echo ""
echo "To install, copy to /Applications:"
echo "  cp -r $APP_NAME.app /Applications/"
echo ""
echo "To run directly:"
echo "  open $APP_NAME.app"
