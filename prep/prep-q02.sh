#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 2 — repository. Menentukan URL repo, menghapus repo EX294_* lama di node.
#   --strict : nonaktifkan repo lain di node (dipindah ke /etc/yum.repos.d.ex294-off), seperti ujian
prefix="$REPO_PREFIX"
if [ -z "$prefix" ] && [ -n "$RHEL_ISO" ]; then
  [ -f "$RHEL_ISO" ] || die "RHEL_ISO=$RHEL_ISO tidak ditemukan"
  mkdir -p "$MAT_ROOT/rhel9"
  mountpoint -q "$MAT_ROOT/rhel9" || mount -o loop,ro "$RHEL_ISO" "$MAT_ROOT/rhel9" || die "Gagal mount ISO"
  grep -q "$MAT_ROOT/rhel9" /etc/fstab || echo "$RHEL_ISO $MAT_ROOT/rhel9 iso9660 loop,ro,nofail 0 0 # ex294-prep" >> /etc/fstab
  restorecon -R "$MAT_ROOT/rhel9" 2>/dev/null || true
  prefix="http://content.example.com/rhel9"
fi
if [ -z "$prefix" ]; then
  first="${ALL_HOSTS%% *}"
  url="$(rrun "$first" "grep -rhoiE '^baseurl[[:space:]]*=[[:space:]]*\S+/BaseOS(/os)?/?' /etc/yum.repos.d/ /etc/yum.repos.d.ex294-off/ 2>/dev/null | grep -vi ex294 | head -1" | sed -E 's/^[^=]*=[[:space:]]*//')"
  [ -n "$url" ] && prefix="$(sed -E 's#/BaseOS(/os)?/?$##I' <<<"$url")"
fi
[ -n "$prefix" ] || die "URL repo tidak terdeteksi. Isi REPO_PREFIX (mis. http://content.example.com/rhel9.3/x86_64/dvd) atau RHEL_ISO di env.sh"
state_set REPO_PREFIX_USED "$prefix"
gpg="$prefix/RPM-GPG-KEY-redhat-release"
first="${ALL_HOSTS%% *}"
rrun "$first" "curl -fsS -o /dev/null '$prefix/BaseOS/repodata/repomd.xml'" || warn "$prefix/BaseOS tidak terjangkau dari $first"
rrun "$first" "curl -fsS -o /dev/null '$gpg'" || warn "GPG key $gpg tidak terjangkau dari $first"

{ rvars; cat <<'EOS'
for f in /etc/yum.repos.d/*.repo; do [ -f "$f" ] && grep -qE '^\[EX294_(BASE|STREAM)\]' "$f" && rm -f "$f"; done
dnf -q clean all >/dev/null 2>&1 || true
EOS
} | on_hosts "$ALL_HOSTS"
if [ "${1:-}" = "--strict" ]; then
  log "Mode strict: repo lain di node dinonaktifkan (dikembalikan oleh cleanup.sh)"
  on_hosts "$ALL_HOSTS" <<'EOS'
mkdir -p /etc/yum.repos.d.ex294-off
for f in /etc/yum.repos.d/*.repo; do [ -f "$f" ] && mv "$f" /etc/yum.repos.d.ex294-off/; done
dnf -q clean all >/dev/null 2>&1 || true
EOS
fi
info_note q02-repo.txt <<INFO
Soal 2 — nilai repository untuk lab ini:
  EX294_BASE   baseurl = $prefix/BaseOS
  EX294_STREAM baseurl = $prefix/AppStream
  gpgkey               = $gpg
INFO
write_lab_info 2>/dev/null || true
log "Soal 2 siap. Nilai repo ditulis di $INFODIR/q02-repo.txt"
