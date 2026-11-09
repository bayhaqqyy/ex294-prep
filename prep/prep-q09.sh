#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 9 — paket. Hapus php, mariadb, dan grup RPM Development Tools.
on_hosts "$DEV_HOSTS $TEST_HOSTS $PROD_HOSTS" <<'EOS'
dnf -y -q remove php mariadb php-common >/dev/null 2>&1 || true
dnf -y -q group remove "RPM Development Tools" >/dev/null 2>&1 || true
EOS
log "Soal 9 siap (butuh repo yang jalan — Soal 2)"
