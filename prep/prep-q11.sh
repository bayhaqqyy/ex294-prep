#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 11 — hardware report.
source "$LIB_DIR/_artifacts.sh"
publish "$FILES_DIR/materials/hwreport.empty" hwreport.empty
on_hosts "$ALL_HOSTS" <<<'rm -f /root/hwreport.txt'
log "Soal 11 siap: http://materials/hwreport.empty"
