#!/usr/bin/env bash
# Release configuration audit (P10/P12): no synthetic/test code, required plist keys,
# background modes limited to those justified, privacy manifest present.
set -u
APP="${1:?path to CallCapture.app}"
BIN="$APP/CallCapture"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }

check "app bundle exists" "[ -f '$BIN' ]"
for sym in SyntheticCaptureEngine FixtureMediaWriter FixtureAssembler SyntheticMediaFactory FixtureRecordingBuilder UITestMode; do
  check "no '$sym' in Release binary" "! strings -a '$BIN' | grep -q '$sym'"
done
PLIST="$APP/Info.plist"
for key in NSMicrophoneUsageDescription NSFaceIDUsageDescription NSPhotoLibraryAddUsageDescription NSSupportsLiveActivities ITSAppUsesNonExemptEncryption; do
  check "Info.plist has $key" "/usr/libexec/PlistBuddy -c 'Print :$key' '$PLIST' >/dev/null 2>&1"
done
MODES=$(/usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' "$PLIST" 2>/dev/null | tr -d ' {}' | grep -v '^Array' | sort | tr '\n' ',')
check "background modes are exactly audio,screen-capture (got: $MODES)" "[ '$MODES' = 'audio,screen-capture,' ]"
check "PrivacyInfo.xcprivacy bundled" "[ -f '$APP/PrivacyInfo.xcprivacy' ]"
check "privacy manifest declares no tracking" "/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTracking' '$APP/PrivacyInfo.xcprivacy' | grep -q false"
check "widget extension embedded" "[ -d '$APP/PlugIns/CallCaptureWidgets.appex' ]"
check "no StoreKit test config in bundle" "! ls '$APP' | grep -q storekit"
check "no network client code (URLSession data tasks) in app binary" "! strings -a '$BIN' | grep -q 'dataTaskWithRequest'"
exit $fail
