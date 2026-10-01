#!/usr/bin/env bash
# Release configuration audit (P10/P12): no synthetic/test code, required plist keys,
# background modes limited to those justified, privacy manifest present.
set -u
APP="${1:?path to CallCapture.app}"
BIN="$APP/CallCapture"
PLIST="$APP/Info.plist"
fail=0
pass() { echo "PASS  $1"; }
bad() { echo "FAIL  $1"; fail=1; }
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$2" 2>/dev/null; }

if [ -f "$BIN" ]; then pass "app binary exists"; else bad "app binary exists ($BIN)"; echo "Audit stopped: no app."; exit 1; fi
for sym in SyntheticCaptureEngine FixtureMediaWriter FixtureAssembler SyntheticMediaFactory FixtureRecordingBuilder UITestMode; do
  if strings -a "$BIN" | grep -q "$sym"; then bad "Release binary contains '$sym'"; else pass "no '$sym' in Release binary"; fi
done
for key in NSMicrophoneUsageDescription NSFaceIDUsageDescription NSPhotoLibraryAddUsageDescription NSSupportsLiveActivities ITSAppUsesNonExemptEncryption; do
  if plist "$key" "$PLIST" >/dev/null; then pass "Info.plist has $key"; else bad "Info.plist missing $key"; fi
done
MODES=$(plist UIBackgroundModes "$PLIST" | tr -d ' {}' | grep -v '^Array' | grep -v '^$' | sort | tr '\n' ',')
if [ "$MODES" = "audio,screen-capture," ]; then pass "background modes exactly audio,screen-capture"; else bad "background modes: $MODES"; fi
if [ -f "$APP/PrivacyInfo.xcprivacy" ]; then pass "PrivacyInfo.xcprivacy bundled"; else bad "PrivacyInfo.xcprivacy missing"; fi
if plist NSPrivacyTracking "$APP/PrivacyInfo.xcprivacy" | grep -q false; then pass "privacy manifest: no tracking"; else bad "privacy manifest tracking flag"; fi
if [ -d "$APP/PlugIns/CallCaptureWidgets.appex" ]; then pass "widget extension embedded"; else bad "widget extension not embedded"; fi
if ls "$APP" | grep -q storekit; then bad "StoreKit test configuration bundled"; else pass "no StoreKit test config in bundle"; fi
if strings -a "$BIN" | grep -q "dataTaskWithRequest"; then bad "network data task symbols found"; else pass "no URLSession data-task client code"; fi
exit $fail
