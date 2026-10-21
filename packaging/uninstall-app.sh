#!/usr/bin/env bash
# Removes ChaoticNotepad.
#   ./uninstall-app.sh            remove a per-user install
#   sudo ./uninstall-app.sh --system   remove a system-wide install
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-app.sh" --uninstall "$@"
