#!/usr/bin/env bash
# =====================================================================
# Bersihkan sisa latihan di managed node (user, LV, haproxy, cron, repo EX294, dll.)
#   ./cleanup.sh            -> reset state node + kembalikan repo yang dinonaktifkan --strict
#   ./cleanup.sh --purge    -> + hapus resource soal buatan prep, alias /etc/hosts, sudoers tambahan, repo git
# Folder kerja $WORKDIR, user latihan, httpd, dan DVD TIDAK dihapus.
# =====================================================================
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
check_ssh

log "Reset state di semua node"
{ users="$(awk '/^ *- *name:/{print $NF}' "$FILES_DIR/materials/user_list.yml" | xargs)"; rvars users STUDENT; cat <<'EOS'
# Soal 2: repo
for f in /etc/yum.repos.d/*.repo; do [ -f "$f" ] && grep -qE '^\[EX294_(BASE|STREAM)\]' "$f" && rm -f "$f"; done
if [ -d /etc/yum.repos.d.ex294-off ]; then mv /etc/yum.repos.d.ex294-off/*.repo /etc/yum.repos.d/ 2>/dev/null; rmdir /etc/yum.repos.d.ex294-off 2>/dev/null; fi
# Soal 5/6/10: web
systemctl disable --now haproxy >/dev/null 2>&1
rm -f /var/www/html/hello.php /var/www/html/index.html /var/www/html/webdev
rm -rf /webdev; semanage fcontext -d '/webdev(/.*)?' >/dev/null 2>&1
# Soal 7/8
[ -f /etc/chrony.conf.ex294-orig ] && mv -f /etc/chrony.conf.ex294-orig /etc/chrony.conf && systemctl restart chronyd 2>/dev/null
sed -i -E 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
# Soal 11/12/13/14
rm -f /root/hwreport.txt /etc/myhosts
printf '\\S\nKernel \\r on an \\m\n\n' > /etc/issue
crontab -r -u natasha >/dev/null 2>&1
# Soal 17
for u in $users; do id "$u" >/dev/null 2>&1 && userdel -r "$u" >/dev/null 2>&1; done
for g in devops opsmgr; do getent group "$g" >/dev/null && groupdel "$g" >/dev/null 2>&1; done
# Soal 18
for m in $(findmnt -rn -o TARGET -S /dev/research/data 2>/dev/null); do umount "$m"; done
lvremove -f research/data >/dev/null 2>&1
if [ -f /var/lib/ex294/research.img ]; then
  vgremove -f research >/dev/null 2>&1
  for l in $(losetup -j /var/lib/ex294/research.img -O NAME -n 2>/dev/null); do pvremove -ff -y "$l" >/dev/null 2>&1; lvmdevices --deldev "$l" >/dev/null 2>&1; losetup -d "$l"; done
  systemctl disable ex294-research-loop >/dev/null 2>&1
  rm -f /var/lib/ex294/research.img /etc/systemd/system/ex294-research-loop.service; systemctl daemon-reload
fi
# Soal 19
umount /newpart1 2>/dev/null; sed -i '\#[[:space:]]/newpart1[[:space:]]#d' /etc/fstab; systemctl daemon-reload
# Soal 21
rm -f /root/sshconf.tar.gz; rm -rf /srv/docs
true
EOS
} | on_hosts "$ALL_HOSTS"

if [ "${1:-}" = "--purge" ]; then
  log "Purge: resource soal, alias /etc/hosts, sudoers tambahan, repo git"
  { rvars STUDENT; cat <<'EOS'
sed -i '/# ex294-prep$/d' /etc/hosts
rm -f "/etc/sudoers.d/ex294-$STUDENT"
EOS
  } | on_hosts "$ALL_HOSTS"
  if [ "$MAT_SERVER" = python ]; then
    systemctl disable --now ex294-materials >/dev/null 2>&1
    rm -f /etc/systemd/system/ex294-materials.service; systemctl daemon-reload
    firewall-cmd --state >/dev/null 2>&1 && firewall-cmd -q --permanent --remove-port="$MAT_PORT/tcp" && firewall-cmd -q --reload
  fi
  # Hanya file yang dibuat prep; isi lain di docroot (DVD, resource Anda sendiri) tidak disentuh
  for f in balancer.tgz phpinfo.tgz ansible-posix.tar.gz community-general.tar.gz rhel_system_roles.tar.gz \
           user_list.yml ex294-docs.tar.gz hwreport.empty hosts.j2 hosts.yml salaries.yml; do
    rm -f "$MAT_ROOT/Rhce/$f"
  done
  mountpoint -q "$MAT_ROOT/rhel9" && umount "$MAT_ROOT/rhel9"
  sed -i "\#$MAT_ROOT/rhel9#d" /etc/fstab
  rm -rf "$GIT_REPO" "$STATE_DIR"
  sed -i '/# ex294-prep$/d' /etc/hosts
  rm -f "/etc/sudoers.d/ex294-$STUDENT"
  log "Mount DVD di /etc/fstab (bertanda # ex294-prep) tetap dibiarkan; hapus manual bila tidak perlu"
fi
log "Cleanup selesai"
