#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 1 — install & konfigurasi Ansible.
#   --full   : uninstall ansible-core & ansible-navigator dari control node (latihan install dari nol)
#   --fresh  : pindahkan $WORKDIR lama ke $WORKDIR.bak-<waktu> (mulai ujian dari kosong)
for a in "$@"; do
  case "$a" in
    --full)  log "Menghapus ansible-core & ansible-navigator"; dnf -y -q remove ansible-core ansible-navigator >/dev/null 2>&1 || true
             pip3 uninstall -y -q ansible-navigator >/dev/null 2>&1 || true ;;
    --fresh) if [ -d "$WORKDIR" ]; then b="$WORKDIR.bak-$(date +%Y%m%d-%H%M%S)"; mv "$WORKDIR" "$b"; log "Folder lama dipindah ke $b"; fi ;;
  esac
done
check_ssh
log "Soal 1 siap. Login: ssh $STUDENT@$CONTROL_IP (atau su - $STUDENT). Folder kerja: $WORKDIR"
