# shellcheck shell=bash
# =====================================================================
# Konfigurasi lab EX294. Nilai diambil dari profil, lalu default di bawah.
#   LAB_PROFILE=selflab (default) -> prep/profiles/selflab.env  (VM pribadi, servera..serverd)
#   LAB_PROFILE=exam              -> prep/profiles/exam.env     (topologi dump, IP 172.25.250.x)
# Semua nilai bisa di-override lewat environment:
#   sudo DEV_HOSTS=servera.lab.example.com ./prep/prep-q06.sh
# =====================================================================
: "${LAB_PROFILE:=selflab}"
_profile="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/profiles/$LAB_PROFILE.env"
# shellcheck source=profiles/selflab.env
[ -f "$_profile" ] && source "$_profile"

# --- Node -------------------------------------------------------------
: "${CONTROL_IP:=10.10.101.91}"              # IP control node (tempat script ini jalan)
: "${DEV_HOSTS:=servera.lab.example.com}"    # pakai nama yang sama dengan inventory jawaban
: "${TEST_HOSTS:=serverb.lab.example.com}"
: "${PROD_HOSTS:=serverc.lab.example.com}"
: "${BAL_HOSTS:=serverd.lab.example.com}"

# Cara script prep/grade masuk ke managed node (sebagai root lewat sudo bila SSH_USER bukan root).
: "${SSH_USER:=student}"
: "${SSH_KEY:=}"                              # kosong = otomatis: key milik SSH_USER (id_ed25519/id_rsa/id_ecdsa)
: "${KEY_TO_ROOT:=no}"                        # yes = setup-lab juga memasang key ke root@node (gaya dump)

# --- User latihan --------------------------------------------------------
: "${STUDENT:=student}"
: "${STUDENT_PW:=redhat}"                     # hanya dipakai bila user belum ada
: "${WORKDIR:=/home/$STUDENT/ansible}"        # folder kerja jawaban
: "${INFODIR:=/home/$STUDENT/ex294}"          # info dari prep (URL repo, FQCN system roles, dll.)

# --- Content server ----------------------------------------------------------
# httpd  : pakai Apache di control node, docroot MAT_ROOT (/var/www/html)
# python : python3 -m http.server di port 80 (ex294-materials.service)
: "${MAT_SERVER:=httpd}"
: "${MAT_ROOT:=/var/www/html}"
: "${MAT_NAMES:=content.example.com content materials}"   # alias /etc/hosts -> CONTROL_IP (bila belum resolve)
: "${MAT_PORT:=80}"
CONTENT_URL="http://content.example.com/Rhce"            # semua resource soal ada di sini

# --- Repo (Soal 2) -------------------------------------------------------
# Kosong = deteksi otomatis dari repo BaseOS yang sudah ada di managed node pertama.
: "${REPO_PREFIX:=}"
: "${REPO_DVD_DEV:=}"                         # mis. /dev/sr0 -> di-mount ke REPO_DVD_DIR oleh setup-lab
: "${REPO_DVD_DIR:=}"
: "${RHEL_ISO:=}"                             # alternatif: path ISO RHEL 9 di control node

# --- Nilai soal -----------------------------------------------------------
: "${NTP_SERVER:=172.25.254.254}"
: "${VAULT_PW:=whenyouwishuponastar}"
: "${SAL_OLD_PW:=insecure8sure}"
: "${SAL_NEW_PW:=bbs2you9527}"
: "${PW_DEVELOPER:=Imadev}"
: "${PW_MANAGER:=Imamgr}"
: "${EE_IMAGE:=utility.lab.example.com/ee-supported-rhel9:latest}"
: "${GIT_REPO:=/srv/git/ex294-playbooks.git}"
: "${GIT_CLONE:=/home/$STUDENT/ex294-playbooks}"

# --- Storage (Soal 18 & 19) ----------------------------------------------
# Soal 18: VG "research" dari file loop (aman, tidak menyentuh disk asli).
# Kalau di node sudah ada VG research di disk asli (dibuat manual), prep tidak mengubahnya.
: "${RESEARCH_BIG_HOSTS:=$DEV_HOSTS $PROD_HOSTS}"   # VG 2 GiB -> LV 1500M muat
: "${RESEARCH_SMALL_HOSTS:=$TEST_HOSTS}"            # VG 1 GiB -> fallback 800M
# Host lain (balancers) sengaja tanpa VG -> harus muncul "vg not found".
# Soal 19: disk kosong di balancers. Kalau tidak ada, cabang "Disk does not exist" yang diuji.
: "${PART_DISK:=vdd}"

ALL_HOSTS="$(printf '%s\n' $DEV_HOSTS $TEST_HOSTS $PROD_HOSTS $BAL_HOSTS | awk 'NF && !s[$0]++' | xargs)"
STATE_DIR=/var/lib/ex294-prep
