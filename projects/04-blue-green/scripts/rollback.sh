#!/usr/bin/env bash
# Move traffic back to the previous color. That color is left running on purpose.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

current="$(active_color)"
target="$(other_color "${current}")"

if ! fetch_app "app-${target}" /health >/dev/null 2>&1; then
  echo "Cannot roll back to ${target}: it is not healthy." >&2
  exit 1
fi

write_upstream "${target}"
compose exec -T proxy nginx -s reload
if ! report="$(wait_for_proxy_color "${target}")"; then
  echo "Rollback did not move the proxy to ${target}." >&2
  exit 1
fi
echo "${target}" > "${ACTIVE_FILE}"
echo "Rolled back to ${target}: ${report}"
