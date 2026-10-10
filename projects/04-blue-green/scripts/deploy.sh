#!/usr/bin/env bash
# Publish a new version on the inactive color, and move traffic only after /health succeeds.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

version="${1:-}"
if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: deploy.sh <version>    example: deploy.sh 1.4.0" >&2
  exit 2
fi

current="$(active_color)"
target="$(other_color "${current}")"
service="app-${target}"

echo "Active color is ${current}. Deploying ${version} to ${target} without moving traffic."

if [[ "${target}" == "blue" ]]; then
  BLUE_VERSION="${version}" compose up -d --build --no-deps --force-recreate app-blue
else
  GREEN_VERSION="${version}" compose up -d --build --no-deps --force-recreate app-green
fi

echo "Waiting for ${target} to pass /health."
healthy=0
for _ in $(seq 1 30); do
  if fetch_app "${service}" /health >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 1
done

if [[ "${healthy}" -ne 1 ]]; then
  echo "Health check failed. Traffic stays on ${current}." >&2
  compose logs --tail=40 "${service}" >&2 || true
  exit 1
fi

echo "Inactive slot is healthy: $(fetch_app "${service}" /version)"
write_upstream "${target}"
compose exec -T proxy nginx -s reload
if ! report="$(wait_for_proxy_color "${target}")"; then
  echo "Switch failed. Restoring traffic to ${current}." >&2
  write_upstream "${current}"
  compose exec -T proxy nginx -s reload
  exit 1
fi
echo "${target}" > "${ACTIVE_FILE}"
echo "Traffic is now on ${target} at version ${version}."
echo "Proxy reports: ${report}"
