# shellcheck shell=bash
# Fungsi bersama untuk setup-lab, prep, grade, cleanup.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$LIB_DIR/env.sh"
FILES_DIR="$LIB_DIR/files"

log()  { printf '\e[1;34m[prep]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[warn]\e[0m %s\n' "$*" >&2; }
die()  { printf '\e[1;31m[fail]\e[0m %s\n' "$*" >&2; exit 1; }

# Semua script dijalankan sebagai root di control node. Kalau belum root, naik lewat sudo.
need_root() {
  [ "$(id -u)" -eq 0 ] && return 0
  exec sudo -E bash "$(readlink -f "$0")" "$@"
}

SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o ConnectTimeout=8)
[ -n "$SSH_KEY" ] && SSH_OPTS+=(-i "$SSH_KEY")

# rexec <host> <perintah-sederhana>   (stdin diteruskan; dijalankan sebagai root di node)
rexec() {
  local h="$1"; shift
  if [ "$SSH_USER" = root ]; then ssh "${SSH_OPTS[@]}" "root@$h" "$*"
  else ssh "${SSH_OPTS[@]}" "$SSH_USER@$h" "sudo -n $*"; fi
}
# rrun <host> <string perintah shell>
rrun() { local h="$1"; shift; rexec "$h" "bash -c $(printf '%q' "$*")" </dev/null; }
# rscript <host>   (script bash dari stdin)
rscript() { rexec "$1" "bash -s"; }

# on_hosts "<h1 h2>"  <<EOF ... EOF   -> jalankan script yang sama di setiap host
on_hosts() {
  local hosts="$1" s h rc=0
  s="$(cat)"
  for h in $hosts; do
    printf '%s\n' "$s" | rscript "$h" || { warn "Gagal di $h"; rc=1; }
  done
  return $rc
}

# Cetak "VAR=nilai" yang aman untuk disisipkan di awal script remote.
rvars() { local v; for v in "$@"; do printf '%s=%q\n' "$v" "${!v}"; done; }

check_ssh() {
  local h bad=0
  for h in $ALL_HOSTS; do
    rrun "$h" true >/dev/null 2>&1 || { warn "Tidak bisa SSH ke $SSH_USER@$h tanpa password"; bad=1; }
  done
  [ $bad -eq 0 ] || die "Pastikan root di control node bisa 'ssh $SSH_USER@<node>' tanpa password (ssh-copy-id), atau atur SSH_USER/SSH_KEY di env.sh"
}

as_student() { runuser -l "$STUDENT" -c "cd $WORKDIR && $*"; }

state_set() {
  mkdir -p "$STATE_DIR"; touch "$STATE_DIR/state.env"
  sed -i "/^$1=/d" "$STATE_DIR/state.env"
  printf '%s=%q\n' "$1" "$2" >> "$STATE_DIR/state.env"
}
state_load() { [ -f "$STATE_DIR/state.env" ] && source "$STATE_DIR/state.env"; return 0; }

# publish <file-sumber> <path-relatif-di-materials>
publish() {
  install -D -m 0644 "$1" "$MAT_ROOT/$2"
  command -v restorecon >/dev/null && restorecon -R "$MAT_ROOT" 2>/dev/null
  return 0
}

need_setup() {
  [ -f "$STATE_DIR/setup.done" ] || die "Jalankan dulu: ./prep/setup-lab.sh"
  state_load
}

# Tulis catatan untuk peserta di $INFODIR/<file>
info_note() {
  install -d -o "$STUDENT" -g "$STUDENT" "$INFODIR"
  cat > "$INFODIR/$1"
  chown "$STUDENT:$STUDENT" "$INFODIR/$1"
}

in_list() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }
