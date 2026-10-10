#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVE_FILE="${ROOT}/.active"

write_upstream() {
  local color="$1"
  cat > "${ROOT}/nginx/active.conf" <<EOF
upstream platform_active {
    server app-${color}:8080;
}

server {
    listen 80;

    location /nginx-health {
        access_log off;
        return 200 "ok\\n";
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://platform_active;
    }
}
EOF
}

active_color() {
  if [[ -f "${ACTIVE_FILE}" ]]; then
    tr -d '[:space:]' < "${ACTIVE_FILE}"
  else
    echo blue
  fi
}

other_color() {
  if [[ "$1" == "blue" ]]; then
    echo green
  else
    echo blue
  fi
}

compose() {
  docker compose -f "${ROOT}/docker-compose.yml" --project-directory "${ROOT}" "$@"
}

# Health and version are read inside the Docker network. Published host ports
# are for a browser; some hosts drop traffic from the host into the bridge.
fetch_app() {
  local service="$1"
  local path="$2"
  compose exec -T "${service}" python3 -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080${path}', timeout=3).read().decode())"
}

fetch_proxy() {
  compose exec -T proxy wget -qO- "http://127.0.0.1${1}"
}

# nginx reload returns as soon as the signal is sent. The next request can
# still hit the old worker, so callers wait until /version shows the new color.
wait_for_proxy_color() {
  local expected="$1"
  local body=""
  local _
  for _ in $(seq 1 20); do
    body="$(fetch_proxy /version 2>/dev/null || true)"
    if [[ "${body}" == *"\"color\": \"${expected}\""* ]]; then
      printf '%s\n' "${body}"
      return 0
    fi
    sleep 0.3
  done
  echo "Proxy did not start serving ${expected}. Last response: ${body:-none}" >&2
  return 1
}
