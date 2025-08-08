#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/ansible"
exec bash scripts/install_ansible_local.sh
