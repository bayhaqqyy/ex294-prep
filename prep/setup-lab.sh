#!/usr/bin/env bash
# =====================================================================
# Setup lab EX294 (sekali saja, jalankan sebagai root di control node).
#  - user greg + sudo NOPASSWD + SSH key ke root@node dan greg@node
#  - alias /etc/hosts "materials" & "content" -> control node (di control & node)
#  - materials server (python http.server, systemd ex294-materials.service)
#  - artefak: role balancer/phpinfo, collections, hwreport.empty, hosts.j2,
#    hosts.yml, salaries.yml (vault), user_list.yml, ex294-docs.tar.gz
# =====================================================================
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
source "$LIB_DIR/_artifacts.sh"
need_root "$@"

log "Cek SSH ke managed node: $ALL_HOSTS"
check_ssh

# ---------------------------------------------------------------- user greg
log "Menyiapkan user $STUDENT di control node"
id "$STUDENT" >/dev/null 2>&1 || useradd -m "$STUDENT"
echo "$STUDENT:$STUDENT_PW" | chpasswd
echo "$STUDENT ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/ex294-$STUDENT"
chmod 440 "/etc/sudoers.d/ex294-$STUDENT"
SHOME="$(getent passwd "$STUDENT" | cut -d: -f6)"
install -d -m 700 -o "$STUDENT" -g "$STUDENT" "$SHOME/.ssh"
[ -f "$SHOME/.ssh/id_ed25519" ] || runuser -u "$STUDENT" -- ssh-keygen -q -t ed25519 -N '' -f "$SHOME/.ssh/id_ed25519"
PUB="$(cat "$SHOME/.ssh/id_ed25519.pub")"

log "Memasang key $STUDENT ke root@node dan $STUDENT@node, alias /etc/hosts"
{ rvars PUB STUDENT STUDENT_PW CONTROL_IP MAT_NAMES; cat <<'EOS'
set -e
add_key() { install -d -m 700 -o "$2" -g "$2" "$1/.ssh"; touch "$1/.ssh/authorized_keys"
            grep -qxF "$PUB" "$1/.ssh/authorized_keys" || echo "$PUB" >> "$1/.ssh/authorized_keys"
            chown "$2:$2" "$1/.ssh/authorized_keys"; chmod 600 "$1/.ssh/authorized_keys"
            restorecon -R "$1/.ssh" 2>/dev/null || true; }
add_key /root root
id "$STUDENT" >/dev/null 2>&1 || useradd -m "$STUDENT"
echo "$STUDENT:$STUDENT_PW" | chpasswd
echo "$STUDENT ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/ex294-$STUDENT"; chmod 440 "/etc/sudoers.d/ex294-$STUDENT"
add_key "$(getent passwd "$STUDENT" | cut -d: -f6)" "$STUDENT"
sed -i '/# ex294-prep$/d' /etc/hosts
echo "$CONTROL_IP $MAT_NAMES # ex294-prep" >> /etc/hosts
EOS
} | on_hosts "$ALL_HOSTS" || die "Gagal menyiapkan sebagian node"

sed -i '/# ex294-prep$/d' /etc/hosts
echo "$CONTROL_IP $MAT_NAMES # ex294-prep" >> /etc/hosts
# known_hosts untuk greg supaya ssh/ansible tidak bertanya fingerprint
for h in $ALL_HOSTS; do ssh-keyscan -T 5 "$h" 2>/dev/null; done > "$SHOME/.ssh/known_hosts.ex294" || true
cat "$SHOME/.ssh/known_hosts.ex294" >> "$SHOME/.ssh/known_hosts" 2>/dev/null || true
sort -u -o "$SHOME/.ssh/known_hosts" "$SHOME/.ssh/known_hosts" 2>/dev/null || true
rm -f "$SHOME/.ssh/known_hosts.ex294"; chown "$STUDENT:$STUDENT" "$SHOME/.ssh/known_hosts" 2>/dev/null || true

# ---------------------------------------------------------------- materials server
log "Menyiapkan materials server di port $MAT_PORT ($MAT_ROOT)"
install -d -m 755 "$MAT_ROOT/Rhce"
if ss -Hltn "sport = :$MAT_PORT" | grep -q . && ! systemctl -q is-active ex294-materials; then
  die "Port $MAT_PORT di control node sudah dipakai proses lain. Hentikan dulu (mis. httpd) atau ubah MAT_PORT."
fi
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
systemctl daemon-reload
systemctl enable --now ex294-materials >/dev/null 2>&1
systemctl restart ex294-materials
if firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd -q --permanent --add-port="$MAT_PORT/tcp" && firewall-cmd -q --reload
fi

# ---------------------------------------------------------------- artefak
python3 -c 'import cryptography, yaml' 2>/dev/null || dnf -y -q install python3-cryptography python3-pyyaml >/dev/null 2>&1 \
  || warn "python3-cryptography / python3-pyyaml belum terpasang (dibutuhkan prep & grader)"
command -v git >/dev/null || dnf -y -q install git >/dev/null 2>&1 || true
log "Membuat artefak latihan"
pub_roles
pub_materials
pub_collections

sleep 1
first="${ALL_HOSTS%% *}"
if rrun "$first" "curl -fsS -o /dev/null http://materials/hwreport.empty && curl -fsS -o /dev/null http://content/Rhce/balancer.tgz"; then
  log "Materials server terjangkau dari $first"
else
  warn "Node $first belum bisa membuka http://materials/ — cek firewall control node / port $MAT_PORT"
fi

mkdir -p "$STATE_DIR"; date > "$STATE_DIR/setup.done"
write_lab_info
log "Setup selesai. Info lab: $INFODIR/README-lab.txt"
log "Lanjut: ./prep/prep-all.sh   (atau prep-qNN.sh per soal)"
