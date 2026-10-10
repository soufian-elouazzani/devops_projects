#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

write_upstream blue
echo blue > "${ACTIVE_FILE}"
compose up -d --build --wait
"$(dirname "$0")/status.sh"
