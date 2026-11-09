#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 19 (bonus) — partisi /dev/$PART_DISK di balancers. Bersihkan disk bila ada & tidak dipakai.
{ rvars PART_DISK; cat <<'EOS'
d=/dev/$PART_DISK
umount /newpart1 2>/dev/null || true
sed -i '\#[[:space:]]/newpart1[[:space:]]#d' /etc/fstab
systemctl daemon-reload
if [ ! -b "$d" ]; then echo "  $(hostname): $d tidak ada -> yang diuji cabang 'Disk does not exist'"; exit 0; fi
if lsblk -nro MOUNTPOINT "$d" | grep -q . || pvs "$d"* >/dev/null 2>&1; then
  echo "  $(hostname): $d sedang dipakai, tidak dibersihkan"; exit 0; fi
for p in $(lsblk -nro NAME "$d" | tail -n +2); do wipefs -aq "/dev/$p"; done
wipefs -aq "$d"; partprobe "$d" 2>/dev/null || true
echo "  $(hostname): $d dibersihkan ($(lsblk -dno SIZE "$d"))"
EOS
} | on_hosts "$BAL_HOSTS"
log "Soal 19 siap"
