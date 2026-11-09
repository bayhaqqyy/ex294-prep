#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 15 — vault baru. Tidak ada yang perlu disiapkan di node.
[ "${1:-}" = "--reset" ] && rm -f "$WORKDIR/locker.yml" "$WORKDIR/secret.txt" && log "locker.yml & secret.txt dihapus"
log "Soal 15 siap"
