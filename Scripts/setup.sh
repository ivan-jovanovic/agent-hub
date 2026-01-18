#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"

echo ""
echo -e "${BLUE}Agent Hub Setup${NC}"
echo "================"
echo ""

MISSING=()
WARNINGS=()

# 1. Check Xcode Command Line Tools
echo -n "Xcode Command Line Tools... "
if xcode-select -p &>/dev/null; then
    echo -e "$CHECK"
else
    echo -e "$CROSS"
    MISSING+=("xcode")
fi

# 2. Check Swift
echo -n "Swift compiler... "
if command -v swift &>/dev/null; then
    SWIFT_VERSION=$(swift --version 2>&1 | head -1)
    echo -e "$CHECK ($SWIFT_VERSION)"
else
    echo -e "$CROSS"
    MISSING+=("swift")
fi

# 3. Check iTerm2
echo -n "iTerm2... "
if [ -d "/Applications/iTerm.app" ]; then
    echo -e "$CHECK"
else
    echo -e "$CROSS"
    MISSING+=("iterm2")
fi

# 4. Check Claude Code CLI
echo -n "Claude Code CLI... "
if command -v claude &>/dev/null; then
    echo -e "$CHECK"
else
    echo -e "$WARN (optional)"
    WARNINGS+=("claude")
fi

# 5. Check Codex CLI
echo -n "Codex CLI... "
if command -v codex &>/dev/null; then
    echo -e "$CHECK"
else
    echo -e "$WARN (optional)"
    WARNINGS+=("codex")
fi

echo ""

# Show missing dependencies
if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${RED}Missing required dependencies:${NC}"
    echo ""

    for dep in "${MISSING[@]}"; do
        case $dep in
            xcode)
                echo "  Xcode Command Line Tools"
                echo -e "  ${BLUE}→ Run: xcode-select --install${NC}"
                echo ""
                ;;
            swift)
                echo "  Swift (included with Xcode CLT)"
                echo -e "  ${BLUE}→ Run: xcode-select --install${NC}"
                echo ""
                ;;
            iterm2)
                echo "  iTerm2"
                echo -e "  ${BLUE}→ brew install --cask iterm2${NC}"
                echo -e "  ${BLUE}→ Or download from: https://iterm2.com${NC}"
                echo ""
                ;;
        esac
    done

    echo "Please install the missing dependencies and run this script again."
    exit 1
fi

# Show warnings for optional dependencies
if [ ${#WARNINGS[@]} -eq 2 ]; then
    echo -e "${YELLOW}Warning:${NC} Neither Claude Code nor Codex CLI is installed."
    echo "You need at least one to use Agent Hub."
    echo ""
    echo "  Claude Code: https://github.com/anthropics/claude-code"
    echo "  Codex CLI:   https://github.com/openai/codex"
    echo ""
fi

# All required deps are installed
echo -e "${GREEN}All required dependencies are installed!${NC}"
echo ""

# Ask to build
read -p "Would you like to build Agent Hub now? [Y/n] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo ""
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    "$SCRIPT_DIR/build.sh"

    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run: open \"Agent Hub.app\""
    echo "  2. Grant automation permission when prompted (for iTerm2)"
    echo "  3. Optionally move the app to /Applications"
else
    echo ""
    echo "To build later, run: ./Scripts/build.sh"
fi
