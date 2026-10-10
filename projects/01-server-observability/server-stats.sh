#!/usr/bin/env bash
# Read-only snapshot of host health: OS, capacity, and the processes using it.
# Exit status is 0 when usage is under the thresholds, 1 when a threshold is exceeded.
set -u

WARN_CPU=80
WARN_MEM=80
WARN_DISK=85
JSON=0

usage() {
  cat <<'EOF'
Usage: server-stats.sh [--json] [--cpu N] [--mem N] [--disk N]

  --json     Print one JSON object instead of a text report
  --cpu N    Warn when CPU usage is at least N percent (default 80)
  --mem N    Warn when memory usage is at least N percent (default 80)
  --disk N   Warn when any real filesystem is at least N percent full (default 85)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --cpu) WARN_CPU="${2:?missing value for --cpu}"; shift 2 ;;
    --mem) WARN_MEM="${2:?missing value for --mem}"; shift 2 ;;
    --disk) WARN_DISK="${2:?missing value for --disk}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/ }
  printf '%s' "$value"
}

cpu_usage() {
  local usage
  usage=$(top -bn1 | awk -F',' '/Cpu|%Cpu/ {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /id/) {
        gsub(/[^0-9.]/, "", $i)
        printf "%.0f", 100 - $i
        exit
      }
    }
  }')
  if [[ -z "${usage}" ]]; then
    echo "0"
  else
    echo "${usage}"
  fi
}

mem_percent() {
  free | awk '/^Mem:/ { if ($2 > 0) printf "%.0f", ($3 / $2) * 100; else print "0" }'
}

disk_max() {
  df -P | awk 'NR > 1 && $1 ~ /^\/dev\// { gsub("%", "", $5); if ($5 + 0 > max) max = $5 } END { print max + 0 }'
}

os_name() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${NAME} ${VERSION:-}"
  else
    uname -sr
  fi
}

failed_logins() {
  local log=""
  if [[ -r /var/log/auth.log ]]; then
    log=/var/log/auth.log
  elif [[ -r /var/log/secure ]]; then
    log=/var/log/secure
  fi
  if [[ -z "${log}" ]]; then
    echo "0"
    return
  fi
  local count
  count="$(grep -c "Failed password" "${log}" 2>/dev/null || true)"
  echo "${count:-0}"
}

CPU=$(cpu_usage)
MEM=$(mem_percent)
DISK=$(disk_max)
OS_SUMMARY=$(os_name)
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null | sed 's/^up //' || echo "unknown")
LOAD=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
USERS=$(who | wc -l | tr -d ' ')
FAILED=$(failed_logins)
IP_ADDR=$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')
IP_ADDR=${IP_ADDR:-unknown}

ALERTS=()
if (( CPU >= WARN_CPU )); then ALERTS+=("cpu"); fi
if (( MEM >= WARN_MEM )); then ALERTS+=("memory"); fi
if (( DISK >= WARN_DISK )); then ALERTS+=("disk"); fi

if (( JSON == 1 )); then
  alert_json="["
  for i in "${!ALERTS[@]}"; do
    [[ $i -gt 0 ]] && alert_json+=","
    alert_json+="\"$(json_escape "${ALERTS[$i]}")\""
  done
  alert_json+="]"
  cat <<EOF
{"os":"$(json_escape "${OS_SUMMARY}")","kernel":"$(json_escape "${KERNEL}")","uptime":"$(json_escape "${UPTIME}")","load":"$(json_escape "${LOAD}")","users":${USERS},"failed_logins":${FAILED},"cpu_percent":${CPU},"memory_percent":${MEM},"disk_percent_max":${DISK},"primary_ip":"$(json_escape "${IP_ADDR}")","alerts":${alert_json}}
EOF
else
  echo "=========================================="
  echo "        HOST HEALTH SNAPSHOT"
  echo "=========================================="
  echo "OS:              ${OS_SUMMARY}"
  echo "Kernel:          ${KERNEL}"
  echo "Uptime:          ${UPTIME}"
  echo "Load (1/5/15):   ${LOAD}"
  echo "Logged-in users: ${USERS}"
  echo "Failed logins:   ${FAILED} (auth log, all retained entries)"
  echo "Primary IP:      ${IP_ADDR}"
  echo
  echo "CPU:             ${CPU}%    (warn >= ${WARN_CPU})"
  echo "Memory:          ${MEM}%    (warn >= ${WARN_MEM})"
  echo "Disk max:        ${DISK}%    (warn >= ${WARN_DISK})"
  echo
  echo "Filesystems"
  df -hP | awk 'NR == 1 || $1 ~ /^\/dev\// || $1 == "tmpfs"'
  echo
  echo "Top 5 processes by CPU"
  ps -eo user,pid,%cpu,%mem,comm --sort=-%cpu | head -n 6
  echo
  echo "Top 5 processes by memory"
  ps -eo user,pid,%cpu,%mem,comm --sort=-%mem | head -n 6
  echo
  if ((${#ALERTS[@]} > 0)); then
    echo "Thresholds exceeded: ${ALERTS[*]}"
  else
    echo "Thresholds: all clear"
  fi
  echo "=========================================="
fi

if ((${#ALERTS[@]} > 0)); then
  exit 1
fi
exit 0
