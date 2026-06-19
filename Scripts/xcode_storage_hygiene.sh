#!/bin/sh

set -eu

xctest_devices_dir="$HOME/Library/Developer/XCTestDevices"
derived_data_dir="$HOME/Library/Developer/Xcode/DerivedData"
core_simulator_dir="$HOME/Library/Developer/CoreSimulator"
threshold_gb="${XCTEST_DEVICES_CLEANUP_THRESHOLD_GB:-5}"
check_only=false

if [ "${1:-}" = "--check-only" ]; then
    check_only=true
elif [ "$#" -gt 0 ]; then
    echo "Usage: $0 [--check-only]" >&2
    exit 2
fi

case "$threshold_gb" in
    ''|*[!0-9]*)
        echo "XCTEST_DEVICES_CLEANUP_THRESHOLD_GB must be a positive integer." >&2
        exit 2
        ;;
    0)
        echo "XCTEST_DEVICES_CLEANUP_THRESHOLD_GB must be greater than zero." >&2
        exit 2
        ;;
esac

directory_size_kb() {
    if [ -d "$1" ]; then
        du -sk "$1" | awk '{ print $1 }'
    else
        echo 0
    fi
}

report_sizes() {
    for directory in "$xctest_devices_dir" "$derived_data_dir" "$core_simulator_dir"; do
        if [ -d "$directory" ]; then
            du -sh "$directory"
        else
            echo "0B\t$directory"
        fi
    done
}

report_sizes

size_kb="$(directory_size_kb "$xctest_devices_dir")"
threshold_kb=$((threshold_gb * 1024 * 1024))

if [ "$size_kb" -lt "$threshold_kb" ]; then
    echo "XCTestDevices is below the ${threshold_gb} GB cleanup threshold."
    exit 0
fi

if [ "$check_only" = true ]; then
    echo "XCTestDevices exceeds the ${threshold_gb} GB cleanup threshold; check-only mode left it unchanged."
    exit 0
fi

if pgrep -x xcodebuild >/dev/null 2>&1 || \
   pgrep -f '/XCTRunner|/xctest|com\.apple\.dt\.XCTest' >/dev/null 2>&1; then
    echo "Xcode tests still appear active; skipped XCTestDevices cleanup." >&2
    exit 0
fi

find "$xctest_devices_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

echo "Cleared XCTestDevices after it exceeded the ${threshold_gb} GB threshold."
du -sh "$xctest_devices_dir"
