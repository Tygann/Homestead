#!/usr/bin/env bash
set -euo pipefail

readonly review_config_dir="/data/homeassistant"

mkdir -p "${review_config_dir}"

# Enforce the isolated component allowlist on every start. UI-managed review
# dashboards and entities remain in .storage, while YAML cannot drift into
# production-network discovery or production Home Assistant access.
cp /seed/configuration.yaml "${review_config_dir}/configuration.yaml"

exec python3 -m homeassistant --config "${review_config_dir}"
