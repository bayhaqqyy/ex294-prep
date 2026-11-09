#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 7 — timesync system role. Kembalikan chrony ke pool default.
on_hosts "$ALL_HOSTS" <<'EOS'
[ -f /etc/chrony.conf.ex294-orig ] || cp -p /etc/chrony.conf /etc/chrony.conf.ex294-orig 2>/dev/null || true
if [ -f /etc/chrony.conf ]; then
  sed -i -E '/^(server|pool|peer)[[:space:]]/d' /etc/chrony.conf
  sed -i '1i pool 2.rhel.pool.ntp.org iburst' /etc/chrony.conf
  systemctl restart chronyd 2>/dev/null || true
fi
EOS
state_load
log "Soal 7 siap. Role: ${SR_FQCN:-redhat.rhel_system_roles}.timesync"
