#!/bin/sh
set -eu

SIMULATOR_ID="${1:-booted}"
OUTPUT_PATH="${2:-PreviewDashboardLayout.json}"
APP_BUNDLE_ID="com.tyler.Homestead"
APP_GROUP_ID="group.com.tyler.Homestead"

GROUPS_OUTPUT="$(xcrun simctl get_app_container "${SIMULATOR_ID}" "${APP_BUNDLE_ID}" groups)"
GROUP_CONTAINER="$(printf '%s\n' "${GROUPS_OUTPUT}" | awk -v group="${APP_GROUP_ID}" '$1 == group { print $2; exit }')"

if [ -z "${GROUP_CONTAINER}" ]; then
    echo "Could not find ${APP_GROUP_ID} for simulator ${SIMULATOR_ID}." >&2
    exit 1
fi

PREFERENCES_PATH="${GROUP_CONTAINER}/Library/Preferences/${APP_GROUP_ID}.plist"
if [ ! -f "${PREFERENCES_PATH}" ]; then
    echo "No Live Preview dashboard preferences found at ${PREFERENCES_PATH}." >&2
    exit 1
fi

python3 - "${PREFERENCES_PATH}" "${OUTPUT_PATH}" <<'PY'
import base64
import json
import os
import plistlib
import sys

preferences_path, output_path = sys.argv[1:]
with open(preferences_path, "rb") as preferences_file:
    preferences = plistlib.load(preferences_file)

document_prefix = "homestead.dashboard.configuration.v3"
selection_prefix = "homestead.dashboard.selectedDashboardID.v3"

data_values = {}
string_values = {}
for key, value in preferences.items():
    if not (key == document_prefix or key.startswith(document_prefix + ".") or
            key == selection_prefix or key.startswith(selection_prefix + ".")):
        continue
    if isinstance(value, bytes):
        data_values[key] = base64.b64encode(value).decode("ascii")
    elif isinstance(value, str):
        string_values[key] = value

if not data_values:
    raise SystemExit("No saved Live Preview dashboard layouts were found.")

backup = {
    "schemaVersion": 1,
    "dataValues": data_values,
    "stringValues": string_values,
}
temporary_path = output_path + ".tmp"
with open(temporary_path, "w", encoding="utf-8") as output_file:
    json.dump(backup, output_file, indent=2, sort_keys=True)
    output_file.write("\n")
os.replace(temporary_path, output_path)

print(f"Saved {len(data_values)} Live Preview dashboard layout(s) to {output_path}.")
PY
