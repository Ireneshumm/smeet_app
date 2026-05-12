#!/usr/bin/env bash
set -e

KEYSTORE_PATH="$HOME/smeet-android-keystore.jks"
KEY_ALIAS="smeet"

if [ -f "$KEYSTORE_PATH" ]; then
  echo "Keystore already exists at $KEYSTORE_PATH"
  echo "Delete it first if you want to regenerate"
  exit 1
fi

read -p "Enter keystore password (save this safely!): " -s STORE_PASSWORD
echo
read -p "Enter key password (can be same as keystore): " -s KEY_PASSWORD
echo

keytool -genkey -v \
  -keystore "$KEYSTORE_PATH" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$KEY_ALIAS" \
  -storepass "$STORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -dname "CN=Irene Shum, OU=Smeet, O=Smeet, L=Brisbane, ST=QLD, C=AU"

echo ""
echo "✅ Keystore generated at: $KEYSTORE_PATH"
echo ""
echo "Next: convert keystore to base64 for GitHub Secrets:"
echo "  macOS:  base64 -i $KEYSTORE_PATH | pbcopy"
echo "  Linux:  base64 -w0 $KEYSTORE_PATH | xclip -selection clipboard   # or copy terminal output"
echo ""
echo "Add these to GitHub → Settings → Secrets and variables → Actions:"
echo "  ANDROID_KEYSTORE_BASE64   (from base64 output above)"
echo "  ANDROID_KEYSTORE_PASSWORD (the keystore password you entered)"
echo "  ANDROID_KEY_PASSWORD      (the key password you entered)"
echo "  ANDROID_KEY_ALIAS         $KEY_ALIAS"
