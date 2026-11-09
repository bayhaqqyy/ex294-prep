#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 17 — user dari user_list.yml. Hapus user & grup lama.
publish "$FILES_DIR/materials/user_list.yml" Rhce/user_list.yml
users="$(awk '/^ *- *name:/{print $NF}' "$FILES_DIR/materials/user_list.yml" | xargs)"
{ rvars users; cat <<'EOS'
for u in $users; do id "$u" >/dev/null 2>&1 && userdel -r "$u" >/dev/null 2>&1; done
for g in devops opsmgr; do getent group "$g" >/dev/null && groupdel "$g" >/dev/null 2>&1; done
true
EOS
} | on_hosts "$ALL_HOSTS"
log "Soal 17 siap: http://content/Rhce/user_list.yml (butuh locker.yml dari Soal 15)"
