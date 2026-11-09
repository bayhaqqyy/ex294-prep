#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 12 — /etc/issue. Kembalikan ke isi default RHEL.
on_hosts "$ALL_HOSTS" <<'EOS'
printf '\\S\nKernel \\r on an \\m\n\n' > /etc/issue
EOS
log "Soal 12 siap"
