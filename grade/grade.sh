#!/usr/bin/env bash
# =====================================================================
# EX294 practice grader — 17 soal inti = 300 poin (lulus 210)
#                         + bonus soal 8, 19, 20, 21 (15 poin masing-masing)
# Jalankan sebagai root di control node (otomatis naik lewat sudo).
# Pemakaian:  ./grade.sh            -> semua soal
#             ./grade.sh 5 11 17    -> soal tertentu
# =====================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
# shellcheck source=../prep/_lib.sh
source "$ROOT/prep/_lib.sh"
need_root "$@"
state_load

SCORE=0; TOTAL=0; BONUS=0; BTOTAL=0; QS=0; QT=0
G='\e[32m'; R='\e[31m'; Y='\e[33m'; B='\e[1m'; N='\e[0m'
VAULT="$ROOT/prep/files/vault.py"

# chk <poin> <deskripsi> <perintah...>   (perintah sukses = dapat poin)
chk() {
  local pts="$1" desc="$2"; shift 2
  QT=$((QT + pts))
  if "$@" >/dev/null 2>&1; then QS=$((QS + pts)); printf "  ${G}PASS${N} %-64s +%s\n" "$desc" "$pts"
  else printf "  ${R}FAIL${N} %-64s  0/%s\n" "$desc" "$pts"; fi
}
begin()     { QS=0; QT=0; printf "\n${B}Soal %s — %s${N}\n" "$1" "$2"; }
end_core()  { SCORE=$((SCORE + QS)); TOTAL=$((TOTAL + QT)); printf "  ${Y}=> %s/%s${N}\n" "$QS" "$QT"; }
end_bonus() { BONUS=$((BONUS + QS)); BTOTAL=$((BTOTAL + QT)); printf "  ${Y}=> bonus %s/%s${N}\n" "$QS" "$QT"; }

# ------------------------------------------------------------------ helper
W="$WORKDIR"
sfile() { [ -f "$W/$1" ] && [ "$(stat -c %U "$W/$1")" = "$STUDENT" ]; }
# all_ok "<hosts>" "<perintah>" -> sukses jika perintah sukses di semua host (daftar tidak kosong)
all_ok() { local h; [ -n "${1// /}" ] || return 1; for h in $1; do rrun "$h" "$2" || return 1; done; }
none_ok() { local h; for h in $1; do rrun "$h" "$2" && return 1; done; return 0; }
fqdn_of()  { rrun "$1" "python3 -c 'import socket;print(socket.getfqdn())'" 2>/dev/null; }
short_of() { rrun "$1" "hostname -s" 2>/dev/null; }
ip_of()    { rrun "$1" "ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if(\$i==\"src\") print \$(i+1)}'" 2>/dev/null | head -1; }
vault_view() { python3 -I "$VAULT" decrypt "$1" "$2"; }   # vault_view <pw> <file>
pyf() { # pyf <file> -- <ekspresi python dgn variabel d (yaml)>
  local f="$1" expr="$3"
  python3 - "$f" "$expr" <<'PY'
import sys, yaml
try:
    d = yaml.safe_load(open(sys.argv[1]))
    ok = eval(sys.argv[2], {"d": d})
except Exception:
    ok = False
sys.exit(0 if ok else 1)
PY
}

# Cache fakta node (fqdn / short / ip)
declare -A FQ SH IP
facts() { local h; for h in $ALL_HOSTS; do [ -n "${FQ[$h]:-}" ] && continue; FQ[$h]="$(fqdn_of "$h")"; SH[$h]="$(short_of "$h")"; IP[$h]="$(ip_of "$h")"; done; }

# ===================================================================== Soal 1
q1_inv() {
  as_student "ansible-inventory -i $W/inventory --list" 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
def hosts(g):
    out=set(d.get(g,{}).get('hosts',[]))
    for c in d.get(g,{}).get('children',[]): out|=hosts(c)
    return out
bal='balancers' if 'balancers' in d else 'balancer'   # dokumen self-lab memakai nama 'balancer'
exp={'dev':'$DEV_HOSTS','test':'$TEST_HOSTS','prod':'$PROD_HOSTS',bal:'$BAL_HOSTS','webservers':'$PROD_HOSTS'}
ok=all(hosts(g)==set(v.split()) for g,v in exp.items()) and 'prod' in d.get('webservers',{}).get('children',[])
sys.exit(0 if ok else 1)"
}
q1_cfg() { # q1_cfg <regex-key> <nilai>
  as_student "ansible-config dump --only-changed" 2>/dev/null | grep -E "^$1\(" | grep -qF "$2"
}
q1_ping() {
  local n; n="$(as_student "ansible all -m ping -o" 2>/dev/null | grep -c 'SUCCESS')"
  [ "$n" -eq "$(wc -w <<<"$ALL_HOSTS")" ]
}
q1_files()   { sfile inventory && sfile ansible.cfg; }
q1_cfgfile() { as_student "ansible --version" 2>/dev/null | grep -q "config file = $W/ansible.cfg"; }
q1_become() {
  local n; n="$(as_student "ansible all -m command -a whoami -o" 2>/dev/null | grep -c '(stdout) root$')"
  [ "$n" -eq "$(wc -w <<<"$ALL_HOSTS")" ]
}
q1() {
  begin 1 "Install & konfigurasi Ansible"
  chk 3 "ansible-core terpasang"                         rpm -q ansible-core
  chk 2 "ansible-navigator tersedia untuk $STUDENT"     runuser -l "$STUDENT" -c "command -v ansible-navigator"
  chk 2 "inventory & ansible.cfg ada, milik $STUDENT"   q1_files
  chk 5 "Grup dev/test/prod/balancers/webservers:children benar" q1_inv
  chk 2 "ansible.cfg dipakai dari $W"                    q1_cfgfile
  chk 2 "inventory = $W/inventory"                       q1_cfg DEFAULT_HOST_LIST "$W/inventory"
  chk 1 "roles_path = $W/roles"                          q1_cfg DEFAULT_ROLES_PATH "$W/roles"
  chk 1 "collections_path = $W/mycollections"            q1_cfg 'COLLECTIONS_PATHS?' "$W/mycollections"
  chk 1 "ansible all -m ping sukses ke semua node"       q1_ping
  chk 1 "Privilege escalation: whoami = root di semua node" q1_become
  end_core
}

# ===================================================================== Soal 2
repo_ok() { # repo_ok <host> <id> <name> <baseurl> <gpgkey>
  rrun "$1" 'cat /etc/yum.repos.d/*.repo 2>/dev/null' | python3 -c "
import sys,configparser
c=configparser.ConfigParser(strict=False,interpolation=None)
try: c.read_string(sys.stdin.read())
except Exception: sys.exit(1)
if '$2' not in c: sys.exit(1)
s=c['$2']; t=('1','yes','true','on')
ok=(s.get('name','').strip()=='$3' and s.get('baseurl','').strip().rstrip('/')=='$4'.rstrip('/')
    and s.get('enabled','1').strip().lower() in t and s.get('gpgcheck','').strip().lower() in t
    and s.get('gpgkey','').strip()=='$5')
sys.exit(0 if ok else 1)"
}
repo_all() { local h; for h in $ALL_HOSTS; do repo_ok "$h" "$@" || return 1; done; }
q2() {
  begin 2 "Repository"
  local p="${REPO_PREFIX_USED:-}"
  [ -n "$p" ] || printf "  ${Y}(prep-q02.sh belum dijalankan, URL repo tidak diketahui)${N}\n"
  chk 2 "yum_repo.yml (atau adhoc.sh executable) ada"   bash -c "[ -f '$W/yum_repo.yml' ] || [ -x '$W/adhoc.sh' ]"
  chk 6 "EX294_BASE benar di semua node"                 repo_all EX294_BASE "EX294 base software" "$p/BaseOS" "$p/RPM-GPG-KEY-redhat-release"
  chk 6 "EX294_STREAM benar di semua node"               repo_all EX294_STREAM "EX294 stream software" "$p/AppStream" "$p/RPM-GPG-KEY-redhat-release"
  chk 3 "dnf repolist menampilkan keduanya (enabled)"    all_ok "$ALL_HOSTS" "dnf -q repolist --enabled | grep -q EX294_BASE && dnf -q repolist --enabled | grep -q EX294_STREAM"
  chk 3 "Metadata EX294_* bisa diunduh"                  all_ok "$ALL_HOSTS" "dnf -q --disablerepo='*' --enablerepo='EX294_*' makecache"
  end_core
}

# ===================================================================== Soal 3
coll_in() { [ -f "$W/mycollections/ansible_collections/${1/.//}/MANIFEST.json" ]; }
q3() {
  begin 3 "Collections"
  local sr="${SR_FQCN:-redhat.rhel_system_roles}"
  chk 2 "Folder $W/mycollections ada"                    test -d "$W/mycollections"
  chk 3 "ansible.posix terpasang di mycollections"       coll_in ansible.posix
  chk 3 "$sr terpasang di mycollections"                 coll_in "$sr"
  chk 3 "community.general terpasang di mycollections"   coll_in community.general
  chk 4 "ansible-galaxy collection list menampilkannya"  bash -c "out=\$(runuser -l $STUDENT -c 'cd $W && ansible-galaxy collection list -p $W/mycollections' 2>/dev/null); grep -q '^ansible.posix ' <<<\"\$out\" && grep -q '^community.general ' <<<\"\$out\" && grep -q '^$sr ' <<<\"\$out\""
  end_core
}

# ===================================================================== Soal 4
q4() {
  begin 4 "Role dari requirements.yml"
  chk 2 "roles/requirements.yml ada"                     test -f "$W/roles/requirements.yml"
  chk 3 "requirements.yml: balancer & phpinfo dari URL"  pyf "$W/roles/requirements.yml" -- \
    "sorted((r.get('name'),r.get('src').replace('/rhce/','/Rhce/')) for r in d)==[('balancer','$CONTENT_URL/balancer.tgz'),('phpinfo','$CONTENT_URL/phpinfo.tgz')]"
  chk 5 "Role balancer terpasang di roles/"              test -f "$W/roles/balancer/tasks/main.yml"
  chk 5 "Role phpinfo terpasang di roles/"               test -f "$W/roles/phpinfo/tasks/main.yml"
  end_core
}

# ===================================================================== Soal 5
q5_hello() { local h; facts; for h in $PROD_HOSTS; do curl -fsS --max-time 5 "http://$h/hello.php" | grep -q "Hello PHP World from ${FQ[$h]}" || return 1; done; }
q5_bal() {
  local b h r seen n_web; facts; n_web="$(wc -w <<<"$PROD_HOSTS")"
  for b in $BAL_HOSTS; do
    seen=""
    for _ in 1 2 3 4; do
      r="$(curl -fsS --max-time 5 "http://$b/" | head -1)"
      for h in $PROD_HOSTS; do grep -q "^Welcome to ${FQ[$h]} on " <<<"$r" && seen="$seen $h"; done
    done
    [ "$(tr ' ' '\n' <<<"$seen" | sort -u | grep -c .)" -ge "$(( n_web < 2 ? n_web : 2 ))" ] || return 1
  done
}
q5() {
  begin 5 "Role balancer & phpinfo"
  chk 3 "roles.yml ada, memakai phpinfo & balancer"      bash -c "grep -q phpinfo '$W/roles.yml' && grep -q balancer '$W/roles.yml'"
  chk 8 "http://<webserver>/hello.php benar di semua prod" q5_hello
  chk 9 "http://<balancer>/ bergantian antar webservers"  q5_bal
  end_core
}

# ===================================================================== Soal 6
q6_page() { local h; facts; for h in $DEV_HOSTS; do [ "$(curl -fsS --max-time 5 "http://$h/" | head -1 | sed 's/[[:space:]]*$//')" = "Welcome to ${FQ[$h]} on ${IP[$h]}" ] || return 1; done; }
q6() {
  begin 6 "Role apache"
  chk 2 "roles/apache/tasks/main.yml ada"                test -f "$W/roles/apache/tasks/main.yml"
  chk 2 "roles/apache/templates/index.html.j2 ada"       test -f "$W/roles/apache/templates/index.html.j2"
  chk 2 "httpd.yml memakai role apache di hosts dev"     pyf "$W/httpd.yml" -- "any(p.get('hosts')=='dev' and 'apache' in str(p.get('roles')) for p in d)"
  chk 4 "httpd terpasang, active & enabled di dev"       all_ok "$DEV_HOSTS" "rpm -q httpd && systemctl is-active httpd && systemctl is-enabled httpd"
  chk 4 "firewalld active+enabled, http permanent+runtime" all_ok "$DEV_HOSTS" "systemctl is-active firewalld && systemctl is-enabled firewalld && firewall-cmd --query-service=http && firewall-cmd --permanent --query-service=http"
  chk 6 "Halaman 'Welcome to <fqdn> on <ip>' benar"      q6_page
  end_core
}

# ===================================================================== Soal 7
q7() {
  begin 7 "timesync system role"
  chk 2 "timesync.yml memakai role timesync"             grep -Eq '(rhel|linux)_system_roles\.timesync' "$W/timesync.yml"
  chk 8 "chrony.conf: server $NTP_SERVER iburst"         all_ok "$ALL_HOSTS" "grep -Eq '^(server|pool)[[:space:]]+${NTP_SERVER//./\\.}[[:space:]].*iburst' /etc/chrony.conf"
  chk 3 "chronyd active & enabled"                       all_ok "$ALL_HOSTS" "systemctl is-active chronyd && systemctl is-enabled chronyd"
  chk 2 "Tidak ada server/pool NTP lain"                 all_ok "$ALL_HOSTS" "! grep -E '^(server|pool)[[:space:]]' /etc/chrony.conf | grep -v '$NTP_SERVER'"
  end_core
}

# ===================================================================== Soal 8 (bonus)
q8() {
  begin 8 "selinux system role (bonus)"
  chk 3 "selinux.yml memakai role selinux"               grep -Eq '(rhel|linux)_system_roles\.selinux' "$W/selinux.yml"
  chk 8 "/etc/selinux/config SELINUX=enforcing"          all_ok "$ALL_HOSTS" "grep -q '^SELINUX=enforcing' /etc/selinux/config && grep -q '^SELINUXTYPE=targeted' /etc/selinux/config"
  chk 4 "getenforce = Enforcing"                         all_ok "$ALL_HOSTS" "[ \"\$(getenforce)\" = Enforcing ]"
  end_bonus
}

# ===================================================================== Soal 9
q9() {
  begin 9 "Paket"
  chk 2 "packages.yml ada"                               test -f "$W/packages.yml"
  chk 5 "php & mariadb di dev, test, prod"               all_ok "$DEV_HOSTS $TEST_HOSTS $PROD_HOSTS" "rpm -q php mariadb"
  chk 5 "Grup 'RPM Development Tools' di dev"            all_ok "$DEV_HOSTS" "dnf -q group list --installed 2>/dev/null | grep -qi 'RPM Development Tools'"
  chk 3 "Tidak ada update tertunda di dev"               all_ok "$DEV_HOSTS" "dnf -q check-update >/dev/null 2>&1"
  end_core
}

# ===================================================================== Soal 10
q10() {
  begin 10 "/webdev"
  local h ok
  chk 2 "webcontent.yml ada"                             test -f "$W/webcontent.yml"
  chk 6 "/webdev: grup webdev, mode 2775"                all_ok "$DEV_HOSTS" "[ \"\$(stat -c '%a %G' /webdev)\" = '2775 webdev' ]"
  chk 3 "Symlink /var/www/html/webdev -> /webdev"        all_ok "$DEV_HOSTS" "[ -L /var/www/html/webdev ] && [ \"\$(readlink -f /var/www/html/webdev)\" = /webdev ]"
  chk 2 "/webdev/index.html berisi Development"          all_ok "$DEV_HOSTS" "grep -qx 'Development' /webdev/index.html"
  chk 2 "Konteks SELinux httpd_sys_content_t"            all_ok "$DEV_HOSTS" "ls -Z /webdev/index.html | grep -q httpd_sys_content_t"
  ok=1; for h in $DEV_HOSTS; do curl -fsS --max-time 5 "http://$h/webdev/" | grep -q '^Development' || ok=0; done
  chk 5 "http://<dev>/webdev/ menampilkan Development"   test "$ok" -eq 1
  end_core
}

# ===================================================================== Soal 11
hw_get() { rrun "$1" "grep -E '^$2=' /root/hwreport.txt | head -1 | cut -d= -f2-"; }
hw_check() { # hw_check <key>
  local h v exp
  for h in $ALL_HOSTS; do
    v="$(hw_get "$h" "$1" 2>/dev/null)"; [ -n "$v" ] || return 1
    case "$1" in
      HOST)   [ "$v" = "$h" ] || return 1 ;;
      MEMORY) exp="$(rrun "$h" "awk '/^MemTotal/{print int(\$2/1024)}' /proc/meminfo")"
              [ "$v" -ge $((exp - 1)) ] 2>/dev/null && [ "$v" -le $((exp + 1)) ] || return 1 ;;
      BIOS)   exp="$(rrun "$h" "cat /sys/class/dmi/id/bios_version 2>/dev/null")"
              if [ -n "$exp" ]; then [ "$v" = "$exp" ] || return 1; else case "$v" in NONE|NA) ;; *) return 1;; esac; fi ;;
      DISK_SIZE_VD?) local d; d="$(tr 'A-Z' 'a-z' <<<"${1##*_}")"
              if rrun "$h" "[ -e /sys/block/$d ]"; then grep -Eq '^[0-9]+(\.[0-9]+)? [KMGTP]?B$' <<<"$v" || return 1
              else [ "$v" = NONE ] || return 1; fi ;;
    esac
  done
}
q11() {
  begin 11 "Hardware report"
  chk 2 "hwreport.yml ada"                               test -f "$W/hwreport.yml"
  chk 1 "/root/hwreport.txt ada di semua node"           all_ok "$ALL_HOSTS" "test -f /root/hwreport.txt"
  chk 4 "HOST = inventory hostname"                      hw_check HOST
  chk 4 "MEMORY = total memori (MB)"                     hw_check MEMORY
  chk 3 "BIOS = versi BIOS (atau NONE)"                  hw_check BIOS
  chk 3 "DISK_SIZE_VDA benar (atau NONE)"                hw_check DISK_SIZE_VDA
  chk 3 "DISK_SIZE_VDB benar (atau NONE)"                hw_check DISK_SIZE_VDB
  end_core
}

# ===================================================================== Soal 12
issue_is() { all_ok "$1" "[ \"\$(sed -e 's/[[:space:]]*\$//' /etc/issue | sed -e '/^\$/d')\" = '$2' ]"; }
q12() {
  begin 12 "/etc/issue"
  chk 2 "issue.yml ada"                                  test -f "$W/issue.yml"
  chk 4 "dev: Development"                               issue_is "$DEV_HOSTS" Development
  chk 4 "test: Test"                                     issue_is "$TEST_HOSTS" Test
  chk 5 "prod: Production"                               issue_is "$PROD_HOSTS" Production
  end_core
}

# ===================================================================== Soal 13
q13_lines() {
  local d h; facts
  for d in $DEV_HOSTS; do
    for h in $ALL_HOSTS; do
      rrun "$d" "grep -Eq '^[[:space:]]*${IP[$h]//./\\.}[[:space:]]+${FQ[$h]//./\\.}[[:space:]]+${SH[$h]}[[:space:]]*\$' /etc/myhosts" || return 1
    done
  done
}
q13() {
  begin 13 "hosts.j2 -> /etc/myhosts"
  chk 2 "hosts.j2 berisi loop groups['all'] + hostvars"  bash -c "grep -q 'groups\[' '$W/hosts.j2' && grep -q hostvars '$W/hosts.j2'"
  chk 3 "/etc/myhosts ada di dev"                        all_ok "$DEV_HOSTS" "test -f /etc/myhosts"
  chk 2 "Dua baris localhost tetap ada"                  all_ok "$DEV_HOSTS" "grep -q '^127.0.0.1' /etc/myhosts && grep -q '^::1' /etc/myhosts"
  chk 13 "Satu baris 'IP FQDN short' untuk tiap host"    q13_lines
  end_core
}

# ===================================================================== Soal 14
q14() {
  begin 14 "Cron"
  chk 2 "cron.yml ada"                                   test -f "$W/cron.yml"
  chk 13 "crontab natasha: */2 * * * * logger \"EX294 in progress\"" all_ok "$ALL_HOSTS" \
    "crontab -l -u natasha 2>/dev/null | grep -Eq '^\\*/2[[:space:]]+\\*[[:space:]]+\\*[[:space:]]+\\*[[:space:]]+\\*[[:space:]]+logger \"EX294 in progress\"[[:space:]]*\$'"
  end_core
}

# ===================================================================== Soal 15
q15_content() {
  vault_view "$VAULT_PW" "$W/locker.yml" | python3 -c "
import sys,yaml; d=yaml.safe_load(sys.stdin)
sys.exit(0 if str(d.get('pw_developer'))=='$PW_DEVELOPER' and str(d.get('pw_manager'))=='$PW_MANAGER' else 1)"
}
q15() {
  begin 15 "Vault locker.yml"
  chk 3 "secret.txt berisi password vault"               bash -c "[ \"\$(head -1 '$W/secret.txt' | tr -d '[:space:]')\" = '$VAULT_PW' ]"
  chk 3 "locker.yml terenkripsi vault"                   bash -c "head -1 '$W/locker.yml' | grep -q '^\$ANSIBLE_VAULT;'"
  chk 7 "Isi: pw_developer=$PW_DEVELOPER, pw_manager=$PW_MANAGER" q15_content
  chk 2 "locker.yml & secret.txt milik $STUDENT"         bash -c "[ \"\$(stat -c %U '$W/locker.yml' '$W/secret.txt' | sort -u)\" = '$STUDENT' ]"
  end_core
}

# ===================================================================== Soal 16
q16_new() { vault_view "$SAL_NEW_PW" "$W/salaries.yml" | grep -q salary_ceo; }
q16_old() { ! vault_view "$SAL_OLD_PW" "$W/salaries.yml"; }
q16() {
  begin 16 "Rekey salaries.yml"
  chk 3 "salaries.yml ada di $W"                         sfile salaries.yml
  chk 2 "Masih terenkripsi"                              bash -c "head -1 '$W/salaries.yml' | grep -q '^\$ANSIBLE_VAULT;'"
  chk 8 "Bisa dibuka dengan password baru"               q16_new
  chk 2 "Password lama sudah tidak berlaku"              q16_old
  end_core
}

# ===================================================================== Soal 17
UL="$ROOT/prep/files/materials/user_list.yml"
ul() { python3 -c "import yaml;[print(u['name'],u['uid'],u['password_expire_days']) for u in yaml.safe_load(open('$UL'))['users'] if u['job']=='$1']"; }
user_ok() { # user_ok <hosts> <job> <group>
  local name uid exp
  while read -r name uid exp; do
    all_ok "$1" "id -u $name | grep -qx $uid && id -nG $name | tr ' ' '\n' | grep -qx $3" || return 1
  done < <(ul "$2")
}
PWCHK=$(cat <<'EOS'
h=$(awk -F: -v u="$name" '$1==u{print $2}' /etc/shadow)
case "$h" in '$6$'*) ;; *) exit 1;; esac
if python3 -c 'import crypt' 2>/dev/null; then
  python3 -c 'import crypt,sys; sys.exit(0 if crypt.crypt(sys.argv[1],sys.argv[2])==sys.argv[2] else 1)' "$pw" "$h"
elif command -v perl >/dev/null; then
  [ "$(perl -e 'print crypt($ARGV[0], $ARGV[1])' "$pw" "$h")" = "$h" ]
else
  salt=$(printf '%s' "$h" | cut -d'$' -f3); [ "$(openssl passwd -6 -salt "$salt" "$pw")" = "$h" ]
fi
EOS
)
pw_ok() { # pw_ok <hosts> <job> <password>
  local name uid exp h pw="$3"
  [ -n "${1// /}" ] || return 1
  while read -r name uid exp; do
    for h in $1; do printf '%s
%s
' "$(rvars name pw)" "$PWCHK" | rscript "$h" || return 1; done
  done < <(ul "$2")
}
exp_ok() { # exp_ok <hosts> <job>
  local name uid exp
  while read -r name uid exp; do
    all_ok "$1" "[ \"\$(awk -F: '\$1==\"$name\"{print \$5}' /etc/shadow)\" = '$exp' ]" || return 1
  done < <(ul "$2")
}
absent_ok() { local name uid exp; while read -r name uid exp; do none_ok "$1" "id $name" || return 1; done < <(ul "$2"); }
q17_place() { absent_ok "$PROD_HOSTS" developer && absent_ok "$DEV_HOSTS $TEST_HOSTS" manager; }
q17() {
  begin 17 "User dari user_list.yml"
  chk 2 "create_users.yml memakai user_list.yml & locker.yml" bash -c "grep -q user_list.yml '$W/create_users.yml' && grep -q locker.yml '$W/create_users.yml'"
  chk 6 "Developer di dev+test: UID & grup devops"       user_ok "$DEV_HOSTS $TEST_HOSTS" developer devops
  chk 3 "Password developer = pw_developer (SHA512)"     pw_ok "$DEV_HOSTS $TEST_HOSTS" developer "$PW_DEVELOPER"
  chk 2 "Password max age developer benar"               exp_ok "$DEV_HOSTS $TEST_HOSTS" developer
  chk 3 "Manager di prod: UID & grup opsmgr"             user_ok "$PROD_HOSTS" manager opsmgr
  chk 2 "Password manager = pw_manager (SHA512)"         pw_ok "$PROD_HOSTS" manager "$PW_MANAGER"
  chk 1 "Password max age manager benar"                 exp_ok "$PROD_HOSTS" manager
  chk 1 "Tidak salah tempat (developer/manager)"         q17_place
  end_core
}

# ===================================================================== Soal 18
# Status per host: "NOVG" atau "<ukuran VG MiB> <ukuran LV data MiB|none> <fstype|none>"
declare -A LVS
lv_state() {
  local h; for h in $ALL_HOSTS; do
    [ -n "${LVS[$h]:-}" ] && continue
    LVS[$h]="$(rrun "$h" '
      vgs research >/dev/null 2>&1 || { echo NOVG; exit 0; }
      vg=$(vgs --noheadings --units m --nosuffix -o vg_size research | xargs | cut -d. -f1)
      lv=$(lvs --noheadings --units m --nosuffix -o lv_size research/data 2>/dev/null | xargs | cut -d. -f1)
      fs=$(blkid -s TYPE -o value /dev/research/data 2>/dev/null)
      echo "$vg ${lv:-none} ${fs:-none}"' 2>/dev/null)"
  done
}
# lv_class big|small -> semua host dengan VG kelas itu punya LV ukuran benar + ext4
lv_class() {
  local h vg lv fs want n=0; lv_state
  for h in $ALL_HOSTS; do
    read -r vg lv fs <<<"${LVS[$h]}"
    [ "$vg" = NOVG ] || [ -z "$vg" ] && continue
    if [ "$vg" -ge 1504 ]; then [ "$1" = big ] || continue; want=1500; else [ "$1" = small ] || continue; want=800; fi
    n=$((n + 1))
    [ "$lv" = "$want" ] && [ "$fs" = ext4 ] || return 1
  done
  [ $n -gt 0 ]    # tidak ada node dengan VG kelas ini = prep-q18.sh belum dijalankan
}
q18_rest() {
  local h; lv_state
  for h in $ALL_HOSTS; do [ -n "${LVS[$h]}" ] || return 1; done
  all_ok "$ALL_HOSTS" '! findmnt -S /dev/research/data && ! grep -q "research" /etc/fstab'
}
q18() {
  begin 18 "LVM research/data"
  lv_state
  for h in $ALL_HOSTS; do printf "  %-28s %s\n" "$h" "${LVS[$h]:-tidak terjangkau}"; done
  grep -qv NOVG <<<"$(printf '%s\n' "${LVS[@]}")" || printf "  ${Y}Belum ada VG research di node mana pun — jalankan prep-q18.sh dulu${N}\n"
  chk 2 "lvm.yml ada"                                    test -f "$W/lvm.yml"
  chk 3 "Pesan 'vg not found' & 'Insufficient size of vg'" bash -c "grep -q 'vg not found' '$W/lvm.yml' && grep -q 'Insufficient size of vg' '$W/lvm.yml'"
  chk 6 "VG >= 1500M: LV data 1500M ext4"                lv_class big
  chk 6 "VG < 1500M: LV data 800M ext4"                  lv_class small
  chk 3 "LV tidak di-mount / tidak di fstab"             q18_rest
  end_core
}

# ===================================================================== Soal 19 (bonus)
q19_part() {
  local h; for h in $BAL_HOSTS; do
    rrun "$h" "
      d=/dev/$PART_DISK
      [ -b \$d ] || { ! findmnt /newpart1; exit \$?; }
      disk=\$((\$(lsblk -bdno SIZE \$d)/1048576)); p=\$((\$(lsblk -bdno SIZE \${d}1)/1048576))
      if [ \$disk -ge 1600 ]; then [ \$p -ge 1400 ] && [ \$p -le 1600 ]; else [ \$p -ge 700 ] && [ \$p -le 900 ]; fi &&
      [ \"\$(blkid -s TYPE -o value \${d}1)\" = ext4 ] && findmnt -S \${d}1 /newpart1 && grep -q '[[:space:]]/newpart1[[:space:]]' /etc/fstab" || return 1
  done
}
q19() {
  begin 19 "Partisi /dev/$PART_DISK (bonus)"
  chk 2 "part.yml ada"                                   test -f "$W/part.yml"
  chk 3 "Pesan 'Could not create...' & 'Disk does not exist'" bash -c "grep -q 'Could not create partition of that size' '$W/part.yml' && grep -q 'Disk does not exist' '$W/part.yml'"
  chk 10 "Partisi benar, ext4, ter-mount persisten (atau disk tidak ada)" q19_part
  end_bonus
}

# ===================================================================== Soal 20 (bonus)
sgit() { runuser -u "$STUDENT" -- git -c safe.directory='*' --git-dir="$GIT_REPO" "$@"; }
q20_tree() { local t; t="$(sgit ls-tree --name-only main)"; grep -qx issue.yml <<<"$t" && grep -qx webcontent.yml <<<"$t"; }
q20_log()  { sgit log --format=%s main | grep -qx 'Add RHCE playbooks'; }
q20() {
  begin 20 "ansible-navigator.yml & Git (bonus)"
  local f="$W/ansible-navigator.yml"
  chk 2 "mode: stdout"                                   pyf "$f" -- "d['ansible-navigator']['mode']=='stdout'"
  chk 2 "playbook-artifact.enable: false"                pyf "$f" -- "d['ansible-navigator']['playbook-artifact']['enable'] in (False,'false')"
  chk 3 "EE image $EE_IMAGE, pull policy missing"        pyf "$f" -- "d['ansible-navigator']['execution-environment']['image']=='$EE_IMAGE' and d['ansible-navigator']['execution-environment']['pull']['policy']=='missing'"
  chk 2 "Clone ada di $GIT_CLONE"                        test -d "$GIT_CLONE/.git"
  chk 4 "main di remote berisi issue.yml & webcontent.yml" q20_tree
  chk 2 "Commit 'Add RHCE playbooks' ada"                q20_log
  end_bonus
}

# ===================================================================== Soal 21 (bonus)
q21() {
  begin 21 "Archive (bonus)"
  chk 2 "archive.yml ada"                                test -f "$W/archive.yml"
  chk 7 "prod: /root/sshconf.tar.gz (gzip) berisi /etc/ssh" all_ok "$PROD_HOSTS" "gzip -t /root/sshconf.tar.gz && tar tzf /root/sshconf.tar.gz | grep -q 'ssh/sshd_config\$'"
  chk 6 "dev: /srv/docs/docs/README.txt hasil ekstrak"   all_ok "$DEV_HOSTS" "test -f /srv/docs/docs/README.txt"
  end_bonus
}

# ------------------------------------------------------------------ main
LIST=("$@"); [ ${#LIST[@]} -gt 0 ] || LIST=($(seq 1 21))
check_ssh
[ -d "$W" ] || printf "${Y}Folder kerja %s belum ada.${N}\n" "$W"
for n in "${LIST[@]}"; do
  declare -f "q$n" >/dev/null || { echo "Soal $n tidak ada"; continue; }
  "q$n"
done

printf "\n${B}===========================================${N}\n"
[ "$TOTAL" -gt 0 ] && printf "${B}Skor inti : %s / %s${N}\n" "$SCORE" "$TOTAL"
[ "$BTOTAL" -gt 0 ] && printf "${B}Bonus     : %s / %s${N}\n" "$BONUS" "$BTOTAL"
if [ "$TOTAL" -eq 300 ]; then
  if [ "$SCORE" -ge 210 ]; then printf "${G}${B}PASS${N} (batas lulus 210)\n"; else printf "${R}${B}NO PASS${N} (batas lulus 210)\n"; fi
fi
