#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

compose down --remove-orphans
