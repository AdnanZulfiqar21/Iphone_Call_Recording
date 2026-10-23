#!/usr/bin/env bash
# Packages a built CallCapture.app as an IPA and writes BUILD_RECORD.txt, the build half of
# the section 19.1 device evidence record (version, build, commit, how it was signed).
# Usage: package_ipa.sh <CallCapture.app> <out.ipa | -> <signing description>
set -euo pipefail
APP="${1:?path to CallCapture.app}"
OUT="${2:?output .ipa path, or - to only write the record}"
SIGNING="${3:?signing description}"
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Info.plist"; }

[ -f "$APP/CallCapture" ] || { echo "no app binary in $APP"; exit 1; }
[ -d "$APP/PlugIns/CallCaptureWidgets.appex" ] || { echo "widget extension not embedded"; exit 1; }

if [ "$OUT" != "-" ]; then
  STAGE="$(mktemp -d)"
  mkdir -p "$STAGE/Payload"
  cp -R "$APP" "$STAGE/Payload/"
  rm -f "$OUT"
  (cd "$STAGE" && zip -qry - Payload) > "$OUT"
  rm -rf "$STAGE"
fi

{
  echo "App:            $(plist CFBundleDisplayName) ($(plist CFBundleIdentifier))"
  echo "Version:        $(plist CFBundleShortVersionString) ($(plist CFBundleVersion))"
  echo "Commit:         ${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
  echo "Branch/ref:     ${GITHUB_REF_NAME:-unknown}"
  echo "CI run:         ${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-local}"
  echo "Configuration:  Release (no synthetic engine or test fixtures; see release-audit.log)"
  echo "Minimum iOS:    $(plist MinimumOSVersion)"
  echo "Signing:        $SIGNING"
  [ "$OUT" != "-" ] && echo "IPA SHA-256:    $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
  echo "Built:          $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee BUILD_RECORD.txt
