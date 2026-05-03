#!/usr/bin/env bash
set -euo pipefail

workspace="MeetingSecondBrain.xcworkspace"
scheme="MeetingAppMobile"
stable_destination="platform=iOS Simulator,name=iPhone 17"
destination="${IOS_TEST_DESTINATION:-}"

show_destinations() {
  xcodebuild -showdestinations \
    -workspace "${workspace}" \
    -scheme "${scheme}" \
    2>&1
}

destination_available() {
  local candidate="$1"
  local destination_name="${candidate##*,name=}"

  show_destinations | grep -Fq "name:${destination_name}"
}

first_available_iphone_destination() {
  show_destinations | awk '
    /platform:iOS Simulator/ && /name:iPhone/ {
      if (match($0, /name:[^,}]+/)) {
        print "platform=iOS Simulator," substr($0, RSTART, RLENGTH)
        exit
      }
    }
  '
}

destination_device_id() {
  local selected="$1"
  local destination_name="${selected##*,name=}"

  show_destinations | awk -v name="name:${destination_name}" '
    index($0, name) && match($0, /id:[^,}]+/) {
      print substr($0, RSTART + 3, RLENGTH - 3)
      exit
    }
  '
}

reset_simulator() {
  local selected="$1"
  local device_id

  device_id="$(destination_device_id "${selected}")"

  if [[ -z "${device_id}" ]]
  then
    return 0
  fi

  xcrun simctl terminate "${device_id}" com.sajor2000.meetingsecondbrain.ios >/dev/null 2>&1 || true
  xcrun simctl uninstall "${device_id}" com.sajor2000.meetingsecondbrain.ios >/dev/null 2>&1 || true
  xcrun simctl shutdown "${device_id}" >/dev/null 2>&1 || true
}

erase_simulator() {
  local selected="$1"
  local device_id

  device_id="$(destination_device_id "${selected}")"

  if [[ -z "${device_id}" ]]
  then
    return 0
  fi

  xcrun simctl shutdown "${device_id}" >/dev/null 2>&1 || true
  xcrun simctl erase "${device_id}" >/dev/null 2>&1 || true
}

run_test() {
  local selected="$1"
  local output_path="$2"

  set +e
  xcodebuild test \
    -workspace "${workspace}" \
    -scheme "${scheme}" \
    -destination "${selected}" \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee "${output_path}"
  local status="${PIPESTATUS[0]}"
  set -e

  return "${status}"
}

if [[ -z "${destination}" ]]
then
  if destination_available "${stable_destination}"
  then
    destination="${stable_destination}"
  else
    destination="$(first_available_iphone_destination)"
  fi

  if [[ -z "${destination}" ]]
  then
    echo "No available iPhone simulator found." >&2
    echo "Install the iOS platform in Xcode Settings > Components, or run: xcodebuild -downloadPlatform iOS" >&2
    echo "If you already have a simulator, set IOS_TEST_DESTINATION to an xcodebuild destination." >&2
    exit 1
  fi
fi

reset_simulator "${destination}"

first_output="$(mktemp -t meeting-app-ios-test.XXXXXX)"
second_output="$(mktemp -t meeting-app-ios-test-retry.XXXXXX)"
trap 'rm -f "${first_output}" "${second_output}"' EXIT

if run_test "${destination}" "${first_output}"
then
  exit 0
fi

if ! grep -Fq "Application failed preflight checks" "${first_output}"
then
  exit 1
fi

erase_simulator "${destination}"

echo "Retrying iOS tests after simulator preflight failure..." >&2

if run_test "${destination}" "${second_output}"
then
  exit 0
fi

echo "iOS tests failed again after retry." >&2
exit 1
