#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
platform="${1:-simulator}"
case "$platform" in
  simulator)
    destination='generic/platform=iOS Simulator'
    signing=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES
      "CODE_SIGN_ENTITLEMENTS=$PWD/Tests/PurchaseTestSimulator.entitlements")
    ;;
  device)
    destination='generic/platform=iOS'
    signing=(CODE_SIGN_IDENTITY='Apple Development' DEVELOPMENT_TEAM=D2J77TZ5H3)
    ;;
  *) printf 'Usage: bash scripts/build-social-test.sh [simulator|device]\n' >&2; exit 1 ;;
esac
swift scripts/prepare-purchase-test.swift --social
xcodebuild -project RKDP.xcodeproj -scheme RKDP -configuration Debug \
  -destination "$destination" -derivedDataPath /private/tmp/RKDPSocialTest \
  -clonedSourcePackagesDirPath /private/tmp/RKDPDerivedData/SourcePackages \
  -disableAutomaticPackageResolution \
  "INFOPLIST_FILE=$PWD/.firebase/puzzlepartytest/SocialTest-Info.plist" \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG PP_SOCIAL_SANDBOX' \
  "${signing[@]}" build
