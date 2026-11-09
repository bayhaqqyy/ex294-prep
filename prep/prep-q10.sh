#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 10 — /webdev. Buat grup webdev, hapus /webdev & symlink.
on_hosts "$DEV_HOSTS" <<'EOS'
getent group webdev >/dev/null || groupadd webdev
rm -rf /webdev; rm -f /var/www/html/webdev
semanage fcontext -d '/webdev(/.*)?' >/dev/null 2>&1 || true
EOS
log "Soal 10 siap (butuh httpd di dev — Soal 6)"
