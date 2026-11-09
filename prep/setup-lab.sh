#!/usr/bin/env bash
# =====================================================================
# Setup lab EX294 (sekali saja, jalankan dengan sudo di control node).
# Tidak mengerjakan jawaban soal; hanya menyiapkan lingkungan:
#  - user latihan ($STUDENT): dibuat bila belum ada, sudo NOPASSWD, SSH key ke node
#  - alias /etc/hosts content.example.com -> control node (hanya bila belum resolve)
#  - content server (httpd docroot /var/www/html, atau python http.server)
#  - DVD RHEL 9 di-mount ke docroot bila REPO_DVD_DEV diisi
#  - resource soal di $CONTENT_URL: role balancer/phpinfo, collections,
#    hwreport.empty, hosts.j2, hosts.yml, salaries.yml (vault), user_list.yml, ex294-docs.tar.gz
# =====================================================================
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
source "$LIB_DIR/_artifacts.sh"
need_root "$@"
log "Profil lab: $LAB_PROFILE · node: $ALL_HOSTS"

# ---------------------------------------------------------------- user latihan (control node)
if ! id "$STUDENT" >/dev/null 2>&1; then
  useradd -m "$STUDENT"; echo "$STUDENT:$STUDENT_PW" | chpasswd; log "User $STUDENT dibuat (password $STUDENT_PW)"
fi
if ! sudo -l -U "$STUDENT" 2>/dev/null | grep -q 'NOPASSWD: ALL'; then
  echo "$STUDENT ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/ex294-$STUDENT"; chmod 440 "/etc/sudoers.d/ex294-$STUDENT"
fi
SHOME="$(getent passwd "$STUDENT" | cut -d: -f6)"
install -d -m 700 -o "$STUDENT" -g "$STUDENT" "$SHOME/.ssh"
PUBF=""
for k in id_ed25519 id_rsa id_ecdsa; do [ -f "$SHOME/.ssh/$k.pub" ] && { PUBF="$SHOME/.ssh/$k.pub"; break; }; done
if [ -z "$PUBF" ]; then
  runuser -u "$STUDENT" -- ssh-keygen -q -t ed25519 -N '' -f "$SHOME/.ssh/id_ed25519"; PUBF="$SHOME/.ssh/id_ed25519.pub"
  log "SSH key baru dibuat untuk $STUDENT"
fi
PUB="$(cat "$PUBF")"
[ "$SSH_USER" = "$STUDENT" ] && [ -z "$SSH_KEY" ] && { SSH_KEY="${PUBF%.pub}"; SSH_OPTS+=(-i "$SSH_KEY"); }

log "Cek SSH ke managed node sebagai $SSH_USER"
check_ssh

# ---------------------------------------------------------------- managed node
log "Menyiapkan $STUDENT, SSH key, dan alias content server di node"
{ rvars PUB STUDENT STUDENT_PW CONTROL_IP MAT_NAMES KEY_TO_ROOT; cat <<'EOS'
set -e
add_key() { install -d -m 700 -o "$2" -g "$2" "$1/.ssh"; touch "$1/.ssh/authorized_keys"
            grep -qxF "$PUB" "$1/.ssh/authorized_keys" || echo "$PUB" >> "$1/.ssh/authorized_keys"
            chown "$2:$2" "$1/.ssh/authorized_keys"; chmod 600 "$1/.ssh/authorized_keys"
            restorecon -R "$1/.ssh" 2>/dev/null || true; }
if ! id "$STUDENT" >/dev/null 2>&1; then useradd -m "$STUDENT"; echo "$STUDENT:$STUDENT_PW" | chpasswd; fi
sudo -l -U "$STUDENT" 2>/dev/null | grep -q 'NOPASSWD: ALL' \
  || { echo "$STUDENT ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/ex294-$STUDENT"; chmod 440 "/etc/sudoers.d/ex294-$STUDENT"; }
add_key "$(getent passwd "$STUDENT" | cut -d: -f6)" "$STUDENT"
[ "$KEY_TO_ROOT" = yes ] && add_key /root root
sed -i '/# ex294-prep$/d' /etc/hosts
miss=""; for n in $MAT_NAMES; do getent hosts "$n" | grep -q "^${CONTROL_IP}[[:space:]]" || miss="$miss $n"; done
[ -z "$miss" ] || echo "$CONTROL_IP$miss # ex294-prep" >> /etc/hosts
EOS
} | on_hosts "$ALL_HOSTS" || die "Gagal menyiapkan sebagian node"

sed -i '/# ex294-prep$/d' /etc/hosts
miss=""; for n in $MAT_NAMES; do getent hosts "$n" | grep -q "^${CONTROL_IP}[[:space:]]" || miss="$miss $n"; done
[ -z "$miss" ] || echo "$CONTROL_IP$miss # ex294-prep" >> /etc/hosts
# known_hosts untuk user latihan supaya ssh/ansible tidak bertanya fingerprint
{ cat "$SHOME/.ssh/known_hosts" 2>/dev/null; for h in $ALL_HOSTS; do ssh-keyscan -T 5 "$h" 2>/dev/null; done; } | sort -u > "$SHOME/.ssh/known_hosts.new" || true
mv -f "$SHOME/.ssh/known_hosts.new" "$SHOME/.ssh/known_hosts"; chown "$STUDENT:$STUDENT" "$SHOME/.ssh/known_hosts"; chmod 644 "$SHOME/.ssh/known_hosts"

# ---------------------------------------------------------------- content server
if [ "$MAT_SERVER" = httpd ]; then
  log "Content server: httpd, docroot $MAT_ROOT"
  rpm -q httpd >/dev/null 2>&1 || dnf -y -q install httpd >/dev/null || die "httpd belum terpasang dan gagal di-install (cek repo di control node)"
  systemctl enable --now httpd >/dev/null 2>&1
else
  log "Content server: python http.server port $MAT_PORT, docroot $MAT_ROOT"
  if ss -Hltn "sport = :$MAT_PORT" | grep -q . && ! systemctl -q is-active ex294-materials; then
    die "Port $MAT_PORT di control node sudah dipakai proses lain. Pakai MAT_SERVER=httpd atau hentikan proses itu."
  fi
  install -d -m 755 "$MAT_ROOT"
  cat > /etc/systemd/system/ex294-materials.service <<EOF
[Unit]
Description=EX294 practice materials web server
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 -m http.server $MAT_PORT --bind 0.0.0.0 --directory $MAT_ROOT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload; systemctl enable ex294-materials >/dev/null 2>&1; systemctl restart ex294-materials
fi
if firewall-cmd --state >/dev/null 2>&1; then
  if [ "$MAT_PORT" = 80 ]; then firewall-cmd -q --permanent --add-service=http; else firewall-cmd -q --permanent --add-port="$MAT_PORT/tcp"; fi
  firewall-cmd -q --reload
fi
install -d -m 755 "$MAT_ROOT/Rhce"
[ -e "$MAT_ROOT/rhce" ] || ln -s Rhce "$MAT_ROOT/rhce"

# DVD RHEL 9 -> docroot (repo Soal 2)
if [ -n "$REPO_DVD_DEV" ] && [ -n "$REPO_DVD_DIR" ]; then
  if [ -d "$REPO_DVD_DIR/BaseOS" ]; then
    log "DVD sudah tersedia di $REPO_DVD_DIR"
  elif [ -b "$REPO_DVD_DEV" ]; then
    mkdir -p "$REPO_DVD_DIR"; mount -o ro "$REPO_DVD_DEV" "$REPO_DVD_DIR" || die "Gagal mount $REPO_DVD_DEV"
    grep -q "[[:space:]]${REPO_DVD_DIR}[[:space:]]" /etc/fstab \
      || echo "$REPO_DVD_DEV $REPO_DVD_DIR iso9660 ro,nofail 0 0 # ex294-prep" >> /etc/fstab
    log "DVD $REPO_DVD_DEV di-mount ke $REPO_DVD_DIR (persisten lewat /etc/fstab)"
  else
    warn "$REPO_DVD_DEV tidak ada dan $REPO_DVD_DIR/BaseOS belum tersedia — attach ISO RHEL 9 dulu"
  fi
  restorecon -R "$MAT_ROOT" 2>/dev/null || true
fi

# ---------------------------------------------------------------- resource soal
python3 -c 'import cryptography, yaml' 2>/dev/null || dnf -y -q install python3-cryptography python3-pyyaml >/dev/null 2>&1 \
  || warn "python3-cryptography / python3-pyyaml belum terpasang (dibutuhkan prep & grader)"
command -v git >/dev/null || dnf -y -q install git >/dev/null 2>&1 || true
log "Membuat resource soal di $MAT_ROOT/Rhce"
pub_roles
pub_materials
pub_collections

sleep 1
first="${ALL_HOSTS%% *}"
if rrun "$first" "curl -fsS -o /dev/null $CONTENT_URL/hwreport.empty && curl -fsS -o /dev/null $CONTENT_URL/balancer.tgz"; then
  log "Resource soal terjangkau dari $first"
else
  warn "$first belum bisa membuka $CONTENT_URL/ — cek httpd/firewall di control node dan /etc/hosts"
fi
if [ -n "$REPO_PREFIX" ]; then
  rrun "$first" "curl -fsS -o /dev/null $REPO_PREFIX/BaseOS/repodata/repomd.xml" \
    && log "Repo DVD terjangkau: $REPO_PREFIX" || warn "$REPO_PREFIX/BaseOS belum terjangkau dari $first"
fi

mkdir -p "$STATE_DIR"; date > "$STATE_DIR/setup.done"
write_lab_info
log "Setup selesai. Info lab: $INFODIR/README-lab.txt"
log "Saran: snapshot semua VM sekarang (EX294-BASELINE), lalu ./prep/prep-all.sh"
