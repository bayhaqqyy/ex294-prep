#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 14 — cron. Pastikan user natasha ada, crontab-nya kosong.
on_hosts "$ALL_HOSTS" <<'EOS'
id natasha >/dev/null 2>&1 || useradd natasha
crontab -r -u natasha >/dev/null 2>&1 || true
EOS
log "Soal 14 siap"
