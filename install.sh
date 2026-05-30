#!/usr/bin/env bash
#
# dexter installer for Linux & macOS.
# Downloads the matching artifact from the latest GitHub Release and installs it.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/OWNER/dexter/main/install.sh | bash
#
# Env overrides:
#   DEXTER_REPO     owner/repo            (default: OWNER/dexter)
#   DEXTER_VERSION  tag, e.g. v0.1.0      (default: latest release)
#   DEXTER_BIN      symlink dir on Linux  (default: $HOME/.local/bin)
#
set -euo pipefail

REPO="${DEXTER_REPO:-OWNER/dexter}"
VERSION="${DEXTER_VERSION:-latest}"
BIN_DIR="${DEXTER_BIN:-$HOME/.local/bin}"
APP="dexter"

err()  { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$1"; }

command -v curl >/dev/null || err "curl required"

# --- detect platform -------------------------------------------------------
os="$(uname -s)"
machine="$(uname -m)"
case "$machine" in
  x86_64|amd64)   arch="x64"   ;;
  aarch64|arm64)  arch="arm64" ;;
  *) err "unsupported architecture: $machine" ;;
esac

case "$os" in
  Linux)
    asset="${APP}-linux-${arch}.tar.gz" ;;
  Darwin)
    asset="${APP}-macos.zip"            # universal binary (arm64 + x86_64)
    command -v unzip >/dev/null || err "unzip required" ;;
  *) err "unsupported OS: $os" ;;
esac

# --- resolve download URL --------------------------------------------------
if [ "$VERSION" = "latest" ]; then
  api="https://api.github.com/repos/${REPO}/releases/latest"
else
  api="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
fi

info "Querying ${REPO} (${VERSION})"
url="$(curl -fsSL "$api" \
  | grep -o "\"browser_download_url\": *\"[^\"]*${asset}\"" \
  | head -n1 | sed 's/.*"\(https[^"]*\)"/\1/')"

[ -n "$url" ] || err "asset '${asset}' not found in ${REPO} ${VERSION}"

# --- download & install ----------------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
info "Downloading ${asset}"
curl -fsSL "$url" -o "$tmp/$asset"

if [ "$os" = "Linux" ]; then
  dest="${XDG_DATA_HOME:-$HOME/.local/share}/${APP}"
  info "Installing to ${dest}"
  rm -rf "$dest"; mkdir -p "$dest"
  tar -xzf "$tmp/$asset" -C "$dest"
  mkdir -p "$BIN_DIR"
  ln -sf "$dest/${APP}" "$BIN_DIR/${APP}"
  info "Linked ${BIN_DIR}/${APP}"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) info "Add to PATH:  export PATH=\"$BIN_DIR:\$PATH\"" ;;
  esac
else
  dest="/Applications"
  info "Installing ${APP}.app to ${dest}"
  unzip -oq "$tmp/$asset" -d "$tmp/extract"
  app_path="$(find "$tmp/extract" -maxdepth 1 -name '*.app' | head -n1)"
  [ -n "$app_path" ] || err "no .app found in archive"
  rm -rf "${dest}/$(basename "$app_path")"
  cp -R "$app_path" "$dest/"
  # Strip quarantine so Gatekeeper doesn't block the unsigned build.
  xattr -dr com.apple.quarantine "${dest}/$(basename "$app_path")" 2>/dev/null || true
fi

info "Done."
