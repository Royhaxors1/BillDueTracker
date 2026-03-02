#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

pick_default_project() {
  local projects
  projects="$(find . -maxdepth 1 -name "*.xcodeproj" -print | sort | sed 's|^\./||')"

  local count
  count="$(printf '%s\n' "${projects}" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ "${count}" -eq 0 ]]; then
    echo "No .xcodeproj found in ${ROOT_DIR}." >&2
    exit 1
  fi
  if [[ "${count}" -gt 1 ]]; then
    echo "Multiple .xcodeproj files found. Set IOS_PROJECT_PATH." >&2
    printf '%s\n' "${projects}" >&2
    exit 1
  fi

  printf '%s\n' "${projects}" | sed '/^$/d' | head -n 1
}

pick_simulator_name() {
  local candidates=(
    "iPhone 17"
    "iPhone 16 Pro"
    "iPhone 16"
    "iPhone 15 Pro"
    "iPhone 15"
    "iPhone 14"
  )

  for candidate in "${candidates[@]}"; do
    if xcrun simctl list devices available | grep -q "${candidate} ("; then
      echo "${candidate}"
      return
    fi
  done

  local first_available
  first_available="$(xcrun simctl list devices available | grep -Eo "iPhone[^\\(]+" | head -n 1 | sed 's/[[:space:]]*$//')"
  if [[ -n "${first_available}" ]]; then
    echo "${first_available}"
    return
  fi

  echo "iPhone 17"
}

PROJECT_PATH="${IOS_PROJECT_PATH:-$(pick_default_project)}"
SCHEME="${IOS_SCHEME:-$(basename "${PROJECT_PATH}" .xcodeproj)}"
SIMULATOR_NAME="${IOS_SIMULATOR_NAME:-$(pick_simulator_name)}"
DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=${SIMULATOR_NAME}}"

echo "==> iOS Verify"
echo "project: ${PROJECT_PATH}"
echo "scheme: ${SCHEME}"
echo "destination: ${DESTINATION}"

echo "==> Build"
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  build

echo "==> Test"
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  test

echo "==> Verification complete"
