#!/usr/bin/env bash
# Production mobile builds: real API over HTTPS, Dart obfuscation, symbols kept for crash decoding.
# Usage: API_BASE_URL=https://api.example.com/api/v1 scripts/build-release.sh [apk|appbundle|ipa]
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-appbundle}"
: "${API_BASE_URL:?Set API_BASE_URL (must be https://)}"
case "$API_BASE_URL" in https://*) ;; *) echo "API_BASE_URL must start with https://" >&2; exit 1;; esac

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
SYMBOLS="build/symbols/$VERSION"   # keep (privately) to de-obfuscate crash reports; never ship or commit

flutter build "$TARGET" --release \
  --obfuscate --split-debug-info="$SYMBOLS" \
  --dart-define=DATA_SOURCE=api \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo "Built $TARGET $VERSION. Archive $SYMBOLS privately for crash symbolication."
