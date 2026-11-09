#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 21 (bonus) — archive/unarchive.
source "$LIB_DIR/_artifacts.sh"
pub_materials
on_hosts "$PROD_HOSTS" <<<'rm -f /root/sshconf.tar.gz'
on_hosts "$DEV_HOSTS"  <<<'rm -rf /srv/docs'
log "Soal 21 siap: http://content/Rhce/ex294-docs.tar.gz"
