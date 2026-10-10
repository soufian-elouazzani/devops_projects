#!/usr/bin/env bash
# Point the Service at blue or green. This drifts from Git until the selector
# in service.yaml matches again. See the GitOps project for the pull-based version.
set -euo pipefail

target="${1:-}"
if [[ "${target}" != "blue" && "${target}" != "green" ]]; then
  echo "usage: switch.sh blue|green" >&2
  exit 2
fi

kubectl -n platform-lab patch service platform-app --type merge \
  -p "{\"spec\":{\"selector\":{\"app\":\"platform-app\",\"color\":\"${target}\"}}}"

echo "Service platform-app now selects color=${target}"
kubectl -n platform-lab get endpoints platform-app
