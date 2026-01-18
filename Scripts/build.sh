#!/bin/bash
set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXECUTABLE_NAME="AgentUI"   # SPM target/binary name (unchanged)
APP_NAME="Agent Hub"        # .app bundle display name
BUILD_DIR="$PROJECT_ROOT/.build"
APP_BUNDLE="$PROJECT_ROOT/$APP_NAME.app"

echo "Building $APP_NAME..."

# Build the executable (use Homebrew Swift if available)
cd "$PROJECT_ROOT"
if [ -x "/opt/homebrew/opt/swift/bin/swift" ]; then
    /opt/homebrew/opt/swift/bin/swift build -c release
else
    swift build -c release
fi

# Find the built executable
EXECUTABLE="$BUILD_DIR/release/$EXECUTABLE_NAME"

if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: Executable not found at $EXECUTABLE"
    exit 1
fi

echo "Creating app bundle..."

# Remove old bundle if exists
rm -rf "$APP_BUNDLE"

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Copy Info.plist
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy entitlements (for reference, not strictly needed for unsigned app)
cp "$PROJECT_ROOT/Resources/AgentUI.entitlements" "$APP_BUNDLE/Contents/Resources/"

# Copy app icon if it exists
if [ -f "$PROJECT_ROOT/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "App icon copied."
fi

echo "App bundle created at: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open $APP_BUNDLE"
