#!/usr/bin/env bash
#
# RoTree installer — one-line install of the `rotree` CLI.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Akrapovich13k/RoTree/main/install.sh | bash
#
# Override the install dir or branch:
#   ROTREE_INSTALL_DIR=/usr/local/bin curl -fsSL ... | bash
#   ROTREE_BRANCH=develop curl -fsSL ... | bash

set -euo pipefail

REPO="${ROTREE_REPO:-Akrapovich13k/RoTree}"
BRANCH="${ROTREE_BRANCH:-main}"
INSTALL_DIR="${ROTREE_INSTALL_DIR:-$HOME/.local/bin}"
SOURCE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/cli/dist/rotree.js"

bold()  { printf "\033[1m%s\033[0m\n" "$1"; }
info()  { printf "  \033[36m→\033[0m %s\n" "$1"; }
ok()    { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn()  { printf "  \033[33m!\033[0m %s\n" "$1"; }
fail()  { printf "  \033[31m✗\033[0m %s\n" "$1" >&2; exit 1; }

bold "RoTree installer"
echo

# 1. Check Node.js
if ! command -v node >/dev/null 2>&1; then
  fail "Node.js 18+ is required but was not found. Install it first: https://nodejs.org"
fi
NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 18 ]; then
  fail "Node.js 18+ is required (you have $(node --version))."
fi
ok "Node.js $(node --version) detected."

# 2. Check curl
if ! command -v curl >/dev/null 2>&1; then
  fail "curl is required."
fi

# 3. Resolve install dir
mkdir -p "$INSTALL_DIR"
TARGET="$INSTALL_DIR/rotree"
info "Installing to $TARGET"

# 4. Download bundled CLI
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
if ! curl -fsSL "$SOURCE_URL" -o "$TMP"; then
  fail "Download failed from $SOURCE_URL"
fi

# Sanity check: must start with a Node shebang
if ! head -1 "$TMP" | grep -q "node"; then
  fail "Downloaded file doesn't look right. Aborting."
fi

mv "$TMP" "$TARGET"
chmod +x "$TARGET"
trap - EXIT
ok "Downloaded and installed."

# 5. Sanity-run
if "$TARGET" version >/dev/null 2>&1; then
  ok "$($TARGET version) works."
else
  fail "Installed file failed to run."
fi

# 6. PATH check
echo
if echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  ok "$INSTALL_DIR is on your PATH."
  echo
  bold "Try it:"
  printf "  rotree help\n  rotree serve\n"
else
  warn "$INSTALL_DIR is NOT on your PATH yet."
  echo
  bold "Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
  printf "  export PATH=\"%s:\$PATH\"\n" "$INSTALL_DIR"
  echo
  bold "Then reload your shell and run:"
  printf "  rotree help\n"
fi
