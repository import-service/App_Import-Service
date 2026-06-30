#!/usr/bin/env bash
# Сборка iOS для App Store (только на macOS с Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> pod install (если есть Podfile / плагины CocoaPods)"
if [[ -f ios/Podfile ]]; then
  (cd ios && pod install)
fi

echo "==> flutter build ipa"
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

echo "==> Готово. IPA: build/ios/ipa/*.ipa"
echo "ITSAppUsesNonExemptEncryption=false в Info.plist — вопрос про шифрование в ASC не спрашивают."
