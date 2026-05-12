#!/usr/bin/env bash
# Bump cache-busting timestamps in web/index.html (and manifest version) before flutter build.
set -euo pipefail

cd "$(dirname "$0")/.."

TIMESTAMP=$(date +%s)
INDEX_FILE="web/index.html"
MANIFEST_FILE="web/manifest.json"

if [ ! -f "$INDEX_FILE" ]; then
  echo "Error: $INDEX_FILE not found"
  exit 1
fi

# Replace Build version comment with current timestamp
sed -i.bak -E "s/<!-- Build version: [0-9]+ -->/<!-- Build version: ${TIMESTAMP} -->/" "$INDEX_FILE"
rm -f "${INDEX_FILE}.bak"

# Cache-busting query strings on script / manifest link
sed -i.bak -E "s/flutter_bootstrap\\.js\\?v=[0-9]+/flutter_bootstrap.js?v=${TIMESTAMP}/g" "$INDEX_FILE"
sed -i.bak -E "s/manifest\\.json\\?v=[0-9]+/manifest.json?v=${TIMESTAMP}/g" "$INDEX_FILE"
rm -f "${INDEX_FILE}.bak"

if [ -f "$MANIFEST_FILE" ]; then
  sed -i.bak -E "s/\"version\": \"[0-9]+\"/\"version\": \"${TIMESTAMP}\"/" "$MANIFEST_FILE"
  rm -f "${MANIFEST_FILE}.bak"
fi

echo "Updated Build version / cache bust to ${TIMESTAMP}"
