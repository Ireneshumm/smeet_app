#!/usr/bin/env bash
# Vercel Linux build: install Flutter stable (shallow clone) and produce build/web.
set -euo pipefail

cd "$(dirname "$0")/.."

export FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter_stable}"

if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  echo ">>> Installing Flutter (stable, shallow clone)..."
  rm -rf "$FLUTTER_ROOT"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

flutter --version
flutter config --no-analytics --enable-web
flutter precache --web
flutter pub get
flutter build web --release

if [[ ! -f build/web/index.html ]]; then
  echo "ERROR: build/web/index.html missing after flutter build web"
  exit 1
fi

echo ">>> build/web ready"
ls -la build/web | head -20
