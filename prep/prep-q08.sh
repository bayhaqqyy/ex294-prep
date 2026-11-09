#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 8 (bonus) — selinux system role. Ubah /etc/selinux/config ke permissive (runtime tidak diubah).
on_hosts "$ALL_HOSTS" <<'EOS'
sed -i -E 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
EOS
state_load
log "Soal 8 siap. Role: ${SR_FQCN:-redhat.rhel_system_roles}.selinux"
