# shellcheck shell=bash
# Pembuat artefak yang disajikan materials server (http://materials, http://content).

# Soal 4/5: role balancer & phpinfo -> $CONTENT_URL/<role>.tgz
pub_roles() {
  local r tmp; tmp="$(mktemp -d)"
  for r in balancer phpinfo; do
    tar czf "$tmp/$r.tgz" --owner=0 --group=0 -C "$FILES_DIR/roles" "$r"
    publish "$tmp/$r.tgz" "Rhce/$r.tgz"
  done
  rm -rf "$tmp"
}

# Soal 11/13/16/17/21: file pendukung (semua di $CONTENT_URL)
pub_materials() {
  local tmp; tmp="$(mktemp -d)"
  publish "$FILES_DIR/materials/hwreport.empty" Rhce/hwreport.empty
  publish "$FILES_DIR/materials/hosts.j2"       Rhce/hosts.j2
  publish "$FILES_DIR/materials/hosts.yml"      Rhce/hosts.yml
  publish "$FILES_DIR/materials/user_list.yml"  Rhce/user_list.yml
  python3 -I "$FILES_DIR/vault.py" encrypt "$SAL_OLD_PW" "$FILES_DIR/materials/salaries.plain" "$tmp/salaries.yml" \
    || die "Gagal membuat salaries.yml (butuh python3-cryptography)"
  publish "$tmp/salaries.yml" Rhce/salaries.yml
  tar czf "$tmp/ex294-docs.tar.gz" --owner=0 --group=0 -C "$FILES_DIR/materials" docs
  publish "$tmp/ex294-docs.tar.gz" Rhce/ex294-docs.tar.gz
  rm -rf "$tmp"
}

# --- Collections (Soal 3) --------------------------------------------------
# Urutan sumber:  1) file di prep/files/collections/*.tar.gz (taruh manual kalau lab offline)
#                 2) Galaxy (butuh internet)   3) ekstrak RPM lewat 'dnf download'
_coll_ok() { tar tzf "$1" MANIFEST.json >/dev/null 2>&1; }
_coll_fqcn() { tar xzf "$1" -O MANIFEST.json 2>/dev/null | python3 -c 'import json,sys;c=json.load(sys.stdin)["collection_info"];print(c["namespace"]+"."+c["name"])'; }

_coll_galaxy() { # ns name ver out
  local url
  for url in "https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/artifacts/$1-$2-$3.tar.gz" \
             "https://galaxy.ansible.com/download/$1-$2-$3.tar.gz"; do
    curl -fsSL --max-time 90 -o "$4.part" "$url" 2>/dev/null && _coll_ok "$4.part" && { mv "$4.part" "$4"; return 0; }
  done
  rm -f "$4.part"; return 1
}
_coll_galaxy_latest() { # ns name out
  local ver
  ver="$(curl -fsSL --max-time 30 "https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/index/$1/$2/" 2>/dev/null \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["highest_version"]["version"])' 2>/dev/null)" || return 1
  [ -n "$ver" ] && _coll_galaxy "$1" "$2" "$ver" "$3"
}
_coll_rpm() { # rpm ns name out
  local tmp d; tmp="$(mktemp -d)"
  ( cd "$tmp" && dnf -q download --destdir "$tmp" "$1" >/dev/null 2>&1 && rpm2cpio ./*.rpm | cpio -idm --quiet 2>/dev/null )
  d="$tmp/usr/share/ansible/collections/ansible_collections/$2/$3"
  if [ -d "$d" ] && python3 -I "$FILES_DIR/mkcoll.py" "$d" "$4" >/dev/null; then rm -rf "$tmp"; return 0; fi
  rm -rf "$tmp"; return 1
}
_coll_local() { # ns name out  -> cari di prep/files/collections
  local f
  for f in "$FILES_DIR"/collections/*.tar.gz; do
    [ -f "$f" ] && _coll_ok "$f" && [ "$(_coll_fqcn "$f")" = "$1.$2" ] && { cp "$f" "$3"; return 0; }
  done
  return 1
}

# Kosongkan dependencies di MANIFEST (system roles dari Galaxy menarik containers.podman dll.)
_coll_nodeps() {
  local tmp; tmp="$(mktemp -d)"
  tar xzf "$1" -C "$tmp" && python3 -I "$FILES_DIR/mkcoll.py" --no-deps "$tmp" "$1.new" >/dev/null && mv "$1.new" "$1"
  local rc=$?; rm -rf "$tmp"; return $rc
}

pub_collections() {
  local tmp out fq; tmp="$(mktemp -d)"
  # ansible.posix
  out="$tmp/ansible-posix.tar.gz"
  if _coll_local ansible posix "$out" || _coll_galaxy ansible posix 1.4.0 "$out" || _coll_rpm ansible-collection-ansible-posix ansible posix "$out"; then
    publish "$out" Rhce/ansible-posix.tar.gz; log "Collection ansible.posix siap"
  else warn "ansible.posix tidak bisa disiapkan. Taruh tarball-nya di prep/files/collections/ lalu ulangi."; fi
  # community.general
  out="$tmp/community-general.tar.gz"
  if _coll_local community general "$out" || _coll_galaxy community general 6.6.0 "$out" || _coll_rpm ansible-collection-community-general community general "$out"; then
    publish "$out" Rhce/community-general.tar.gz; log "Collection community.general siap"
  else warn "community.general tidak bisa disiapkan. Taruh tarball-nya di prep/files/collections/ lalu ulangi."; fi
  # system roles: redhat.rhel_system_roles (RPM) -> fallback fedora.linux_system_roles (Galaxy)
  out="$tmp/system-roles.tar.gz"
  if _coll_local redhat rhel_system_roles "$out" || _coll_rpm rhel-system-roles redhat rhel_system_roles "$out" \
     || _coll_local fedora linux_system_roles "$out" || _coll_galaxy_latest fedora linux_system_roles "$out"; then
    fq="$(_coll_fqcn "$out")"
    _coll_nodeps "$out" || warn "Gagal menghapus dependencies dari $fq (install offline bisa gagal)"
    publish "$out" Rhce/rhel_system_roles.tar.gz
    state_set SR_FQCN "$fq"
    log "Collection system roles siap: $fq"
  else
    warn "System roles tidak bisa disiapkan (rhel-system-roles tidak ada di repo, Galaxy tidak terjangkau)."
    warn "Taruh redhat-rhel_system_roles-*.tar.gz di prep/files/collections/ lalu ulangi."
  fi
  rm -rf "$tmp"
}

write_lab_info() {
  state_load
  info_note README-lab.txt <<EOF
EX294 practice lab — info dari prep (dibuat $(date '+%F %T'))

Profil lab   : $LAB_PROFILE
Control node : $CONTROL_IP   (user $STUDENT, folder kerja $WORKDIR)
dev          : $DEV_HOSTS
test         : $TEST_HOSTS
prod         : $PROD_HOSTS
balancers    : $BAL_HOSTS

Resource soal: $CONTENT_URL/   (disajikan dari control node, $MAT_ROOT/Rhce)
System roles : ${SR_FQCN:-belum disiapkan}   -> role timesync = ${SR_FQCN:-redhat.rhel_system_roles}.timesync
Repo (Soal 2): ${REPO_PREFIX_USED:-jalankan prep-q02.sh}
EOF
}
