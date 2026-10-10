#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

active="$(active_color)"
echo "Recorded active color: ${active}"
echo "Proxy  $(fetch_proxy /version 2>/dev/null || echo unreachable)"
echo "Blue   $(fetch_app app-blue /version 2>/dev/null || echo unreachable)"
echo "Green  $(fetch_app app-green /version 2>/dev/null || echo unreachable)"

host_proxy="$(curl -fsS --noproxy '*' --max-time 1 http://127.0.0.1:8080/version 2>/dev/null || true)"
if [[ -n "${host_proxy}" ]]; then
  echo "Host :8080 ${host_proxy}"
else
  echo "Host port 8080 did not answer. Ports 8080, 8081, and 8082 are still published."
  echo "If they hang, the host is dropping traffic into the Docker bridge. The lines above are the cutover."
fi
