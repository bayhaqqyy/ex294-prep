#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 5 — balancer + phpinfo. Reset haproxy di balancers dan hello.php di webservers.
on_hosts "$BAL_HOSTS" <<'EOS'
systemctl disable --now haproxy >/dev/null 2>&1 || true
dnf -y -q remove haproxy >/dev/null 2>&1 || true
EOS
on_hosts "$PROD_HOSTS" <<'EOS'
rm -f /var/www/html/hello.php /var/www/html/index.html
EOS
log "Soal 5 siap (jalankan Soal 4 dulu agar role tersedia)"
