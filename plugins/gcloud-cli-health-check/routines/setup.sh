#!/usr/bin/env bash
# Cloud-environment setup script for the gcloud CLI health check Routine.
# Runs once per cloud environment build (result is cached).
#
# Purpose: install gcloud SDK on the Linux cloud runtime and authenticate
# using a service account key stored in the GCLOUD_SA_KEY env var.
set -euo pipefail

echo "[setup] gcloud CLI health check Routine — environment bootstrap"
echo "[setup] date:  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[setup] uname: $(uname -a)"

# --- 1. Install gcloud if missing --------------------------------------------
if command -v gcloud >/dev/null 2>&1; then
  echo "[setup] gcloud already present: $(gcloud version --format='value(Google Cloud SDK)' 2>/dev/null || gcloud version | head -n1)"
else
  echo "[setup] gcloud not found — installing from upstream tarball"
  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64|arm64) GCARCH=arm     ;;
    x86_64|amd64)  GCARCH=x86_64 ;;
    *) echo "[setup] unsupported arch: $ARCH" >&2; exit 1 ;;
  esac
  SDK_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${GCARCH}.tar.gz"
  echo "[setup] downloading from $SDK_URL"
  curl -fsSL -o /tmp/gcloud.tar.gz "$SDK_URL"
  tar -xzf /tmp/gcloud.tar.gz -C /tmp/
  # Install — prefer system-wide, fall back to user-local
  if sudo -n true 2>/dev/null; then
    sudo /tmp/google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=true
    source /tmp/google-cloud-sdk/path.bash.inc 2>/dev/null || true
  else
    /tmp/google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=true \
      --install-dir="$HOME/.local"
    source "$HOME/.local/google-cloud-sdk/path.bash.inc" 2>/dev/null || true
    export PATH="$HOME/.local/google-cloud-sdk/bin:$PATH"
  fi
  echo "[setup] installed: $(gcloud version | head -n1)"
fi

# --- 2. Authenticate via service account key ---------------------------------
# Store the service account JSON as GCLOUD_SA_KEY in the Routine environment.
# Generate a key for opsagent-runtime-sa@opsagent-prod.iam.gserviceaccount.com
# (or a dedicated health-check-sa) and paste the entire JSON as the env var value.
if [[ -n "${GCLOUD_SA_KEY:-}" ]]; then
  echo "[setup] activating service account from GCLOUD_SA_KEY"
  echo "$GCLOUD_SA_KEY" > /tmp/sa-key.json
  gcloud auth activate-service-account --key-file=/tmp/sa-key.json
  rm -f /tmp/sa-key.json   # don't leave key on disk
  echo "[setup] auth: OK"
else
  echo "[setup] WARNING: GCLOUD_SA_KEY not set — gcloud commands will be unauthenticated" >&2
fi

# --- 3. Set default project + region -----------------------------------------
gcloud config set project opsagent-prod       --quiet 2>/dev/null || true
gcloud config set compute/region me-west1     --quiet 2>/dev/null || true
gcloud config set core/disable_usage_reporting true --quiet 2>/dev/null || true

# --- 4. Smoke check ----------------------------------------------------------
echo "[setup] smoke check:"
gcloud auth list 2>&1 | head -5
gcloud config get-value project 2>/dev/null

echo "[setup] done"
