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
  *) printf 'Usage: bash scripts/build-ranked-test.sh [simulator|device]\n' >&2; exit 1 ;;
esac
swift scripts/prepare-purchase-test.swift --ranked
xcodebuild -project RKDP.xcodeproj -scheme RKDP -configuration Debug \
  -destination "$destination" -derivedDataPath /private/tmp/RKDPRankedTest \
  -clonedSourcePackagesDirPath /private/tmp/RKDPDerivedData/SourcePackages \
  -disableAutomaticPackageResolution \
  "INFOPLIST_FILE=$PWD/.firebase/puzzlepartytest/RankedTest-Info.plist" \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG PP_SOCIAL_SANDBOX PP_RANKED_SANDBOX' \
  "${signing[@]}" build
