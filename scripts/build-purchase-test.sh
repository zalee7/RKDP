#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Same bundle ID is required for the existing Apple products. Installation is
# deliberately separate: do not overwrite someone's normal app automatically.
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
  *) printf 'Usage: bash scripts/build-purchase-test.sh [simulator|device]\n' >&2; exit 1 ;;
esac

swift scripts/prepare-purchase-test.swift
xcodebuild -project RKDP.xcodeproj -scheme RKDP -configuration Debug \
  -destination "$destination" -derivedDataPath /private/tmp/RKDPPurchaseTest \
  -clonedSourcePackagesDirPath /private/tmp/RKDPDerivedData/SourcePackages \
  -disableAutomaticPackageResolution \
  "INFOPLIST_FILE=$PWD/.firebase/puzzlepartytest/PurchaseTest-Info.plist" \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG PP_PURCHASE_SANDBOX' \
  "${signing[@]}" build
