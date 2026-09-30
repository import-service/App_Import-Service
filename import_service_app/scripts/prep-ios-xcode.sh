#!/usr/bin/env bash
# Подготовка МП для открытия/сборки в Xcode.
# Синхронизирует FLUTTER_BUILD_NAME/NUMBER из pubspec → ios/Flutter/Generated.xcconfig
# (одного `flutter pub get` недостаточно — Xcode иначе показывает старую версию).
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OPEN_XCODE=1
NO_PODS=0
for arg in "$@"; do
  case "$arg" in
    --no-open) OPEN_XCODE=0 ;;
    --no-pods) NO_PODS=1 ;;
    -h|--help)
      echo "Usage: $0 [--no-open] [--no-pods]"
      echo "  Syncs pubspec version into iOS Flutter config, pods, optional open Xcode."
      exit 0
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: prep-ios-xcode.sh только на macOS." >&2
  exit 1
fi

VERSION_LINE="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
NAME="${VERSION_LINE%%+*}"
NUMBER="${VERSION_LINE##*+}"
if [[ -z "$NAME" || -z "$NUMBER" || "$NAME" == "$NUMBER" ]]; then
  echo "ERROR: не разобрал version из pubspec.yaml: '$VERSION_LINE'" >&2
  exit 1
fi

echo "==> pubspec: $VERSION_LINE  (name=$NAME build=$NUMBER)"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build ios --config-only (обновить Generated.xcconfig)"
flutter build ios --config-only --no-codesign

GEN="ios/Flutter/Generated.xcconfig"
if [[ ! -f "$GEN" ]]; then
  echo "ERROR: нет $GEN после config-only" >&2
  exit 1
fi

GOT_NAME="$(grep -E '^FLUTTER_BUILD_NAME=' "$GEN" | cut -d= -f2)"
GOT_NUMBER="$(grep -E '^FLUTTER_BUILD_NUMBER=' "$GEN" | cut -d= -f2)"
if [[ "$GOT_NAME" != "$NAME" || "$GOT_NUMBER" != "$NUMBER" ]]; then
  echo "ERROR: после sync в $GEN всё ещё $GOT_NAME+$GOT_NUMBER, ожидали $NAME+$NUMBER" >&2
  exit 1
fi
echo "==> OK: $GEN → $GOT_NAME+$GOT_NUMBER"

if [[ "$NO_PODS" -eq 0 && -f ios/Podfile ]]; then
  echo "==> pod install"
  (cd ios && pod install)
fi

WS="ios/Runner.xcworkspace"
if [[ "$OPEN_XCODE" -eq 1 ]]; then
  echo "==> open $WS"
  open "$WS"
fi

echo ""
echo "Готово для Xcode: v$NAME ($NUMBER)."
echo "В Xcode: схема Runner → General → Version/Build должны быть $NAME / $NUMBER"
echo "(берутся из FLUTTER_BUILD_* через Generated.xcconfig)."
