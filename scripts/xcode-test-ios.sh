#!/usr/bin/env bash
set -euo pipefail

destination="${IOS_TEST_DESTINATION:-}"

if [[ -z "${destination}" ]]
then
  device_name="$(xcrun simctl list devices available | awk -F '[()]' '
    /iPhone/ && /Shutdown|Booted/ {
      gsub(/^[ \t]+|[ \t]+$/, "", $1)
      print $1
      exit
    }
  ')"

  if [[ -z "${device_name}" ]]
  then
    echo "No available iPhone simulator found." >&2
    echo "Install the iOS platform in Xcode Settings > Components, or run: xcodebuild -downloadPlatform iOS" >&2
    echo "If you already have a simulator, set IOS_TEST_DESTINATION to an xcodebuild destination." >&2
    exit 1
  fi

  destination="platform=iOS Simulator,name=${device_name}"
fi

xcodebuild test \
  -workspace MeetingSecondBrain.xcworkspace \
  -scheme MeetingAppMobile \
  -destination "${destination}" \
  CODE_SIGNING_ALLOWED=NO
