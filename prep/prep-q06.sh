#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 6 — role apache di grup dev. Reset httpd & halaman index di dev.
on_hosts "$DEV_HOSTS" <<'EOS'
systemctl disable --now httpd >/dev/null 2>&1 || true
rm -f /var/www/html/index.html
if firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd -q --permanent --remove-service=http 2>/dev/null; firewall-cmd -q --reload
fi
EOS
log "Soal 6 siap"
