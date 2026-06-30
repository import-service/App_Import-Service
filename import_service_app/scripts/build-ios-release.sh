#!/usr/bin/env bash
# Сборка iOS для App Store (только на macOS с Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> pod install (если есть Podfile)"
if [[ -f ios/Podfile ]]; then
  (cd ios && pod install)
fi

echo "==> flutter build ipa"
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

IPA="$(ls -1 build/ios/ipa/*.ipa | head -1)"
echo "==> Готово: $IPA"
echo ""
echo "Загрузка в App Store Connect:"
echo "  1) Transporter (Mac App Store) — перетащить IPA"
echo "  2) или: xcrun altool --upload-app -f \"$IPA\" -t ios -u APPLE_ID -p APP_SPECIFIC_PASSWORD"
echo ""
echo "Перед первой сборкой в Xcode (Runner → Signing): Team + Automatic signing."
echo "Push: Runner.entitlements (aps-environment), Firebase iOS appId, APNs key в Firebase Console."
echo "ITSAppUsesNonExemptEncryption=false — вопрос про шифрование в ASC не спрашивают."
