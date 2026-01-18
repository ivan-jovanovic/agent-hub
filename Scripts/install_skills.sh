#!/usr/bin/env bash
set -euo pipefail

# Install this repo's skills into Codex CLI's skills directory.
# Usage:
#   Scripts/install_skills.sh             # symlink by default
#   INSTALL_MODE=copy Scripts/install_skills.sh   # copy instead of symlink

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills/public"
CODEX_HOME_DEFAULT="$HOME/.codex"
CODEX_HOME="${CODEX_HOME:-$CODEX_HOME_DEFAULT}"
DEST_DIR="$CODEX_HOME/skills/public"
MODE="${INSTALL_MODE:-symlink}"

echo "Installing skills from: $SRC_DIR"
echo "Target Codex skills dir: $DEST_DIR"
echo "Mode: $MODE"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "No skills found at $SRC_DIR; aborting." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

count=0
skipped=0
for skill_path in "$SRC_DIR"/*; do
  [[ -d "$skill_path" ]] || continue
  skill_name="$(basename "$skill_path")"
  dest="$DEST_DIR/$skill_name"

  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "Skip: $skill_name (already exists at $dest)"
    skipped=$((skipped+1))
    continue
  fi

  if [[ "$MODE" == "copy" ]]; then
    cp -R "$skill_path" "$dest"
  else
    ln -s "$skill_path" "$dest"
  fi
  echo "Installed: $skill_name -> $dest"
  count=$((count+1))
done

echo "Done. Installed: $count, Skipped (exists): $skipped"

