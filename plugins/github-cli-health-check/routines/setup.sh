#!/usr/bin/env bash
# Cloud-environment setup script for the GitHub CLI health check Routine.
# Runs once per cloud environment build (result is cached).
#
# Purpose: make sure `gh` is on PATH and authenticated using the token the
# Claude Code cloud runtime provides via GITHUB_TOKEN.
set -euo pipefail

echo "[setup] GitHub CLI health check Routine — environment bootstrap"
echo "[setup] date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[setup] uname:  $(uname -a)"

# --- 1. Install gh if missing --------------------------------------------------
if command -v gh >/dev/null 2>&1; then
  echo "[setup] gh already present: $(gh --version | head -n1)"
else
  echo "[setup] gh not found — installing from upstream tarball"
  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64|arm64) GHARCH=arm64 ;;
    x86_64|amd64)  GHARCH=amd64 ;;
    *) echo "[setup] unsupported arch: $ARCH" >&2; exit 1 ;;
  esac
  GHVER="${GH_VERSION:-2.89.0}"
  URL="https://github.com/cli/cli/releases/download/v${GHVER}/gh_${GHVER}_linux_${GHARCH}.tar.gz"
  curl -fsSL -o /tmp/gh.tgz "$URL"
  tar -xzf /tmp/gh.tgz -C /tmp/
  # Try system-wide install first (may need sudo). Fall back to user-local.
  if sudo -n true 2>/dev/null; then
    sudo install -m 0755 "/tmp/gh_${GHVER}_linux_${GHARCH}/bin/gh" /usr/local/bin/gh
  else
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "/tmp/gh_${GHVER}_linux_${GHARCH}/bin/gh" "$HOME/.local/bin/gh"
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) ;;
      *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" ;;
    esac
    export PATH="$HOME/.local/bin:$PATH"
  fi
  echo "[setup] installed: $(gh --version | head -n1)"
fi

# --- 2. Wire up authentication -------------------------------------------------
# The Claude Code cloud runtime exposes the user's GitHub token as GITHUB_TOKEN.
# gh reads GH_TOKEN first, so re-export under that name.
if [[ -n "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
  echo "[setup] exporting GH_TOKEN from GITHUB_TOKEN"
  export GH_TOKEN="$GITHUB_TOKEN"
  # Persist for subsequent shells in this session
  echo 'export GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"' >> "$HOME/.bashrc"
fi

# --- 3. Smoke check ------------------------------------------------------------
if [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
  if gh auth status 2>&1 | grep -qE 'Logged in|active account'; then
    echo "[setup] auth: OK"
  else
    echo "[setup] auth: not logged in (token present but gh rejected it)" >&2
  fi
else
  echo "[setup] auth: no GITHUB_TOKEN / GH_TOKEN in environment" >&2
fi

echo "[setup] done"
