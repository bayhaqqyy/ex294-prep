# shellcheck shell=bash
# =====================================================================
# Konfigurasi lab EX294. Semua nilai bisa di-override lewat environment:
#   DEV_HOSTS="10.0.0.11" ./prep/prep-q06.sh
# Default mengikuti dump ujian (control node 172.25.250.254).
# =====================================================================

# --- Node -------------------------------------------------------------
: "${CONTROL_IP:=172.25.250.254}"            # IP control node (tempat script ini jalan)
: "${DEV_HOSTS:=172.25.250.9}"
: "${TEST_HOSTS:=172.25.250.10}"
: "${PROD_HOSTS:=172.25.250.11 172.25.250.12}"
: "${BAL_HOSTS:=172.25.250.13}"

# Cara script prep/grade masuk ke managed node.
# root + SSH key (seperti ujian). Kalau lab Anda hanya punya key untuk user lain
# (mis. student di classroom RH294), isi SSH_USER=student; script akan pakai sudo -n.
: "${SSH_USER:=root}"
: "${SSH_KEY:=}"                              # kosong = key default ~/.ssh milik root

# --- User latihan --------------------------------------------------------
: "${STUDENT:=greg}"
: "${STUDENT_PW:=redhat}"
: "${WORKDIR:=/home/$STUDENT/ansible}"        # folder kerja jawaban
: "${INFODIR:=/home/$STUDENT/ex294}"          # info dari prep (URL repo, FQCN system roles, dll.)

# --- Materials server (pengganti http://materials dan http://content di ujian) ---
: "${MAT_ROOT:=/srv/ex294-materials}"
: "${MAT_NAMES:=materials content}"           # alias /etc/hosts -> CONTROL_IP
: "${MAT_PORT:=80}"

# --- Repo (Soal 2) -------------------------------------------------------
# Kosong = deteksi otomatis dari repo BaseOS yang sudah ada di managed node pertama.
# Contoh classroom: http://content.example.com/rhel9.3/x86_64/dvd
: "${REPO_PREFIX:=}"
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
# Soal 18: VG "research" dibuat dari file loop (aman, tidak menyentuh disk asli).
: "${RESEARCH_BIG_HOSTS:=$DEV_HOSTS $TEST_HOSTS}"   # VG 2 GiB  -> LV 1500M muat
: "${RESEARCH_SMALL_HOSTS:=$PROD_HOSTS}"            # VG 1 GiB  -> fallback 800M
# Host lain (balancers) sengaja tanpa VG -> harus muncul "vg not found".
# Soal 19: disk kosong di balancers. Kalau tidak ada, cabang "Disk does not exist" yang diuji.
: "${PART_DISK:=vdd}"

ALL_HOSTS="$(printf '%s\n' $DEV_HOSTS $TEST_HOSTS $PROD_HOSTS $BAL_HOSTS | awk 'NF && !s[$0]++' | xargs)"
STATE_DIR=/var/lib/ex294-prep
