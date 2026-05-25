#!/usr/bin/env bash
#
# RoTree installer — one-line install of the `rotree` CLI.
#
# Two install modes, picked automatically:
#   1. Standalone binary (no Node required) — preferred when a published
#      release is available for your platform. Bigger download (~50 MB),
#      zero runtime dependencies.
#   2. Node.js bundle (~290 KB) — used when Node 18+ is already installed,
#      OR when no matching binary is published (e.g. branch installs).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Akrapovich13k/RoTree/main/install.sh | bash
#
# Overrides:
#   ROTREE_INSTALL_DIR=/usr/local/bin   target directory
#   ROTREE_BRANCH=develop               use a non-main branch (bundle mode only)
#   ROTREE_VERSION=v0.1.0               pin a specific release tag
#   ROTREE_MODE=binary|bundle|auto      force a mode (default: auto)
#
# Examples:
#   ROTREE_MODE=binary curl -fsSL ... | bash    # force binary even if Node is present
#   ROTREE_MODE=bundle curl -fsSL ... | bash    # force JS bundle even if a binary exists

set -euo pipefail

REPO="${ROTREE_REPO:-Akrapovich13k/RoTree}"
BRANCH="${ROTREE_BRANCH:-main}"
INSTALL_DIR="${ROTREE_INSTALL_DIR:-$HOME/.local/bin}"
MODE="${ROTREE_MODE:-auto}"
VERSION="${ROTREE_VERSION:-latest}"

bold()  { printf "\033[1m%s\033[0m\n" "$1"; }
info()  { printf "  \033[36m→\033[0m %s\n" "$1"; }
ok()    { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn()  { printf "  \033[33m!\033[0m %s\n" "$1"; }
fail()  { printf "  \033[31m✗\033[0m %s\n" "$1" >&2; exit 1; }

bold "RoTree installer"
echo

command -v curl >/dev/null 2>&1 || fail "curl is required."

# Detect platform
UNAME_S=$(uname -s)
UNAME_M=$(uname -m)
case "$UNAME_S" in
  Linux)  OS="linux" ;;
  Darwin) OS="darwin" ;;
  *)      OS="unknown" ;;
esac
case "$UNAME_M" in
  x86_64|amd64) ARCH="x64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *)             ARCH="unknown" ;;
esac
info "platform: $OS-$ARCH"

# Resolve release tag
release_tag() {
  if [ "$VERSION" = "latest" ]; then
    # Resolve via redirect — no auth required for public repos.
    local url="https://github.com/${REPO}/releases/latest"
    local resolved
    resolved=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$url" 2>/dev/null || echo "")
    echo "${resolved##*/}"
  else
    echo "$VERSION"
  fi
}

binary_url() {
  local tag="$1"
  echo "https://github.com/${REPO}/releases/download/${tag}/rotree-${OS}-${ARCH}"
}

bundle_url() {
  echo "https://raw.githubusercontent.com/${REPO}/${BRANCH}/cli/dist/rotree.js"
}

# Decide mode
HAS_NODE=0
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo "0")
  if [ "$NODE_MAJOR" -ge 18 ]; then HAS_NODE=1; fi
fi

USE_BINARY=0
if [ "$MODE" = "binary" ]; then
  USE_BINARY=1
elif [ "$MODE" = "bundle" ]; then
  USE_BINARY=0
elif [ "$MODE" = "auto" ]; then
  # Auto: binary unless Node is already installed (bundle is then smaller + faster).
  if [ "$HAS_NODE" -eq 1 ]; then
    USE_BINARY=0
  else
    USE_BINARY=1
  fi
fi

mkdir -p "$INSTALL_DIR"
TARGET="$INSTALL_DIR/rotree"

# ── Binary path ────────────────────────────────────────────────────────
install_binary() {
  if [ "$OS" = "unknown" ] || [ "$ARCH" = "unknown" ]; then
    return 1
  fi
  local tag url
  tag=$(release_tag)
  if [ -z "$tag" ] || [ "$tag" = "releases" ]; then
    warn "No published release found yet — falling back to the JS bundle."
    return 1
  fi
  url=$(binary_url "$tag")
  info "downloading standalone binary $tag for $OS-$ARCH"
  info "URL: $url"

  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  if ! curl -fSL "$url" -o "$TMP"; then
    warn "Binary download failed. Falling back to JS bundle."
    rm -f "$TMP"
    trap - EXIT
    return 1
  fi
  # Heuristic sanity check: > 1 MB and ELF/Mach-O magic bytes.
  size=$(wc -c <"$TMP")
  if [ "$size" -lt 1000000 ]; then
    warn "Downloaded file is suspiciously small ($size bytes). Aborting."
    rm -f "$TMP"
    trap - EXIT
    return 1
  fi
  mv "$TMP" "$TARGET"
  chmod +x "$TARGET"
  trap - EXIT
  ok "Installed standalone binary to $TARGET"
  return 0
}

# ── Node-bundle path ───────────────────────────────────────────────────
install_bundle() {
  if [ "$HAS_NODE" -eq 0 ]; then
    printf "\n"
    warn "Node.js 18+ is required for the bundle install path."
    printf "\n"
    printf "  Pick whichever fits your system:\n"
    if [ "$(uname)" = "Darwin" ]; then
      printf "    \033[36mbrew install node\033[0m                # macOS, Homebrew\n"
    fi
    if command -v apt-get >/dev/null 2>&1; then
      printf "    \033[36msudo apt-get install -y nodejs\033[0m   # Debian/Ubuntu\n"
    fi
    if command -v dnf >/dev/null 2>&1; then
      printf "    \033[36msudo dnf install -y nodejs\033[0m       # Fedora/RHEL\n"
    fi
    if command -v pacman >/dev/null 2>&1; then
      printf "    \033[36msudo pacman -S nodejs\033[0m            # Arch\n"
    fi
    printf "    \033[36mcurl -fsSL https://fnm.vercel.app/install | bash && fnm install 20\033[0m\n"
    printf "                                          # any platform, no root\n"
    printf "\n"
    printf "  Or skip Node entirely with the standalone binary:\n"
    printf "    \033[36mROTREE_MODE=binary curl -fsSL https://raw.githubusercontent.com/%s/main/install.sh | bash\033[0m\n" "$REPO"
    printf "\n"
    fail "Re-run this script once Node.js is on your PATH."
  fi
  ok "Node.js $(node --version) detected."

  local url
  url=$(bundle_url)
  info "downloading JS bundle from $url"
  TMP=$(mktemp)
  trap 'rm -f "$TMP"' EXIT
  if ! curl -fsSL "$url" -o "$TMP"; then
    fail "Download failed from $url"
  fi
  if ! head -1 "$TMP" | grep -q "node"; then
    fail "Downloaded bundle doesn't look right. Aborting."
  fi
  mv "$TMP" "$TARGET"
  chmod +x "$TARGET"
  trap - EXIT
  ok "Installed JS bundle to $TARGET (needs Node 18+ on PATH)."
}

if [ "$USE_BINARY" -eq 1 ]; then
  if ! install_binary; then
    install_bundle
  fi
else
  install_bundle
fi

# Sanity-run
if "$TARGET" version >/dev/null 2>&1; then
  ok "$($TARGET version) works."
else
  fail "Installed file failed to run."
fi

# PATH check
echo
if echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  ok "$INSTALL_DIR is on your PATH."
else
  warn "$INSTALL_DIR is NOT on your PATH yet."
  echo
  bold "Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
  printf "  export PATH=\"%s:\$PATH\"\n" "$INSTALL_DIR"
  echo
fi

# Offer to auto-configure the AI client's MCP. Skipped when piped from curl.
echo
if [ -t 0 ] && [ -t 1 ]; then
  bold "Configure your AI client (Claude Code / Claude Desktop) now? [y/N]"
  read -r REPLY
  case "$REPLY" in
    [yY]|[yY][eE][sS])
      if "$TARGET" mcp-install --cwd "$PWD"; then
        ok "MCP configured for $PWD"
      else
        warn "mcp-install returned non-zero. You can re-run it later: rotree mcp-install"
      fi
      ;;
    *)
      info "Skipped. To configure later: rotree mcp-install --cwd <your-roblox-project>"
      ;;
  esac
else
  echo
  bold "Next:"
  printf "  cd <your-roblox-project>\n"
  printf "  rotree mcp-install        # auto-configures Claude Code / Desktop\n"
  printf "  rotree mcp                # start the bridge + MCP server\n"
fi
