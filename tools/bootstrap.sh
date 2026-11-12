#!/usr/bin/env bash
# android/ ve ios/ klasörlerini üretir (yoksa) ve PlayVue yamalarını uygular.
# Kullanım: tools/bootstrap.sh [android|ios|all]
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:-all}"

need_gen=0
{ [ "$TARGET" != "ios" ] && [ ! -d android ]; } && need_gen=1
{ [ "$TARGET" != "android" ] && [ ! -d ios ]; } && need_gen=1

if [ "$need_gen" = "1" ]; then
  TMP="$(mktemp -d)"
  flutter create --org com.playvue --project-name playvue --platforms=android,ios "$TMP/playvue"
  [ -d android ] || cp -R "$TMP/playvue/android" android
  [ -d ios ] || cp -R "$TMP/playvue/ios" ios
  rm -rf "$TMP"
fi

if [ "$TARGET" != "ios" ]; then
  python3 tools/patch_android.py
  # Eklentilerin eski compileSdk değerini yükselt (Gradle init betiği)
  INIT_DIR="${GRADLE_USER_HOME:-$HOME/.gradle}/init.d"
  mkdir -p "$INIT_DIR"
  cp tools/compilesdk.init.gradle "$INIT_DIR/compilesdk.gradle"
  echo "Gradle init betiği kuruldu: $INIT_DIR/compilesdk.gradle"
fi

if [ "$TARGET" != "android" ]; then
  python3 tools/patch_ios.py
  if [ -f ios/Podfile ]; then
    sed -i.bak -E "s/^#? ?platform :ios, .*/platform :ios, '13.0'/" ios/Podfile && rm -f ios/Podfile.bak
  fi
  if [ -f ios/Runner.xcodeproj/project.pbxproj ]; then
    sed -i.bak -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g" ios/Runner.xcodeproj/project.pbxproj && rm -f ios/Runner.xcodeproj/project.pbxproj.bak
  fi
fi
echo "Bootstrap tamam ($TARGET)"
