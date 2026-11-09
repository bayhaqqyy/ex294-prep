#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 16 — rekey. Publikasikan ulang salaries.yml (password lama: $SAL_OLD_PW).
source "$LIB_DIR/_artifacts.sh"
pub_materials
rm -f "$WORKDIR/salaries.yml"
log "Soal 16 siap: $CONTENT_URL/salaries.yml"
