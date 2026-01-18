#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXECUTABLE_NAME="AgentUI"
APP_NAME="Agent Hub"
APP_BUNDLE="$PROJECT_ROOT/$APP_NAME.app"

# Build first
"$SCRIPT_DIR/build.sh"

# Kill existing instance if running
pkill -f "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" 2>/dev/null || true

echo ""
echo "Launching $APP_NAME..."
open "$APP_BUNDLE"
