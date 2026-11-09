#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 13 — /etc/myhosts dari template.
publish "$FILES_DIR/materials/hosts.j2"  Rhce/hosts.j2
publish "$FILES_DIR/materials/hosts.yml" Rhce/hosts.yml
on_hosts "$ALL_HOSTS" <<<'rm -f /etc/myhosts'
[ "${1:-}" = "--reset" ] && rm -f "$WORKDIR/hosts.j2" "$WORKDIR/hosts.yml"
log "Soal 13 siap: $CONTENT_URL/hosts.j2 , $CONTENT_URL/hosts.yml"
