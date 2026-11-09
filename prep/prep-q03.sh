#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 3 — collections. Memastikan tarball tersedia di http://content/Rhce/.
#   --reset : hapus isi $WORKDIR/mycollections
source "$LIB_DIR/_artifacts.sh"
for c in ansible-posix community-general rhel_system_roles; do
  [ -f "$MAT_ROOT/Rhce/$c.tar.gz" ] || { log "Menyiapkan ulang collections"; pub_collections; break; }
done
[ "${1:-}" = "--reset" ] && rm -rf "$WORKDIR/mycollections" && log "mycollections dihapus"
state_load
log "Soal 3 siap. System roles di lab ini: ${SR_FQCN:-TIDAK ADA}"
