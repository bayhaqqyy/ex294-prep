#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 20 (bonus) — ansible-navigator.yml + Git. Membuat repo bare $GIT_REPO.
#   --reset : hapus clone lama $GIT_CLONE dan $WORKDIR/ansible-navigator.yml
command -v git >/dev/null || dnf -y -q install git >/dev/null || die "git tidak terpasang"
rm -rf "$GIT_REPO"; install -d -o "$STUDENT" -g "$STUDENT" "$(dirname "$GIT_REPO")"
runuser -u "$STUDENT" -- git init -q --bare -b main "$GIT_REPO" 2>/dev/null \
  || { runuser -u "$STUDENT" -- git init -q --bare "$GIT_REPO" && runuser -u "$STUDENT" -- git --git-dir="$GIT_REPO" symbolic-ref HEAD refs/heads/main; }
tmp="$(runuser -u "$STUDENT" -- mktemp -d)"
runuser -u "$STUDENT" -- bash -c "cd '$tmp' && git init -q -b main 2>/dev/null || { git init -q && git checkout -q -b main; }
  git config user.name 'EX294 Lab'; git config user.email lab@example.com
  printf '# EX294 playbooks\n' > README.md && git add README.md && git commit -qm 'Initial commit' && git push -q '$GIT_REPO' main"
rm -rf "$tmp"
if [ "${1:-}" = "--reset" ]; then rm -rf "$GIT_CLONE" "$WORKDIR/ansible-navigator.yml"; log "Clone & ansible-navigator.yml lama dihapus"; fi
log "Soal 20 siap: repo $GIT_REPO (branch main)"
