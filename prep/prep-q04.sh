#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 4 — role dari URL. Mempublikasikan balancer.tgz & phpinfo.tgz.
#   --reset : hapus roles/balancer & roles/phpinfo di $WORKDIR
source "$LIB_DIR/_artifacts.sh"
pub_roles
[ "${1:-}" = "--reset" ] && rm -rf "$WORKDIR/roles/balancer" "$WORKDIR/roles/phpinfo" && log "Role lama dihapus"
log "Soal 4 siap: $CONTENT_URL/balancer.tgz , $CONTENT_URL/phpinfo.tgz"
