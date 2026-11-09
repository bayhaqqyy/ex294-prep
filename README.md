# EX294 Prep — Latihan Red Hat Certified Engineer (RHCE, RHEL 9)

Set latihan untuk ujian **EX294**. Pola soalnya diambil dari dump *RHCE EXAM V9* (`rhce_v1.5.pdf`, update 1/1/2026). Jawaban dump yang salah sudah dikoreksi, dan soal tambahan dibuat untuk objektif resmi yang tidak dibahas dump (ansible-navigator.yml, Git, archiving).

| File | Isi |
|---|---|
| [`SOAL.md`](SOAL.md) | 17 soal inti (300 poin, lulus 210) + 4 soal bonus (60 poin). Bahasa Inggris, gaya ujian |
| [`KUNCI.md`](KUNCI.md) | Kunci jawaban lengkap (bahasa Indonesia) + tabel koreksi dari dump |
| `prep/` | `setup-lab.sh` (sekali), `prep-qNN.sh` per soal, `prep-all.sh`, `cleanup.sh`, `env.sh` |
| `grade/grade.sh` | Grader otomatis dengan nilai parsial per item |

## Peta objektif

| Objektif resmi EX294 | Soal |
|---|---|
| Install & konfigurasi control node, `ansible.cfg`, inventory statis + grup anak | 1 |
| Repository paket (playbook / ad-hoc) | 2 |
| Content collections dari URL, `collections_path` | 3 |
| Role: install dari requirements file, pakai di playbook, buat role sendiri | 4, 5, 6 |
| RHEL system roles (timesync / selinux) | 7, 8 (bonus) |
| Paket, grup paket, update | 9 |
| File, permission khusus, symlink, SELinux context, firewall, service | 10, 6 |
| Facts, loop, `default`, `lineinfile`, `get_url` | 11 |
| Kondisi `when` per grup | 12, 17 |
| Template Jinja2 dengan `hostvars` | 13 |
| Task scheduling (cron) | 14 |
| Ansible Vault: create, password file, rekey, pakai di playbook | 15, 16, 17 |
| Users & groups, password hash | 17 |
| Storage: LVM, partisi, filesystem, mount, error handling `block/rescue` | 18, 19 (bonus) |
| `ansible-navigator.yml`, Git clone/add/commit/push | 20 (bonus) |
| Archiving | 21 (bonus) |

Di ujian asli hanya muncul **salah satu** dari Soal 7/8 dan **salah satu** dari Soal 18/19, sesuai catatan di dump. Karena itu 8 dan 19 dijadikan bonus.

## Cara pakai

Semua script dijalankan **di control node sebagai root** (otomatis pakai `sudo` kalau belum root). Jawaban dikerjakan sebagai `greg`.

```bash
git clone https://github.com/bayhaqqyy/ex294-prep.git ~/ex294-prep
cd ~/ex294-prep
vi prep/env.sh                   # sesuaikan IP node, SSH_USER, repo
chmod +x prep/*.sh grade/*.sh

sudo ./prep/setup-lab.sh         # sekali: user greg, SSH key, materials server, artefak
sudo ./prep/prep-all.sh          # siapkan semua soal
sudo ./prep/prep-all.sh 2 18     # atau beberapa soal saja
sudo ./prep/prep-q02.sh --strict # repo lain di node dimatikan, seperti ujian

su - greg                        # kerjakan soal di /home/greg/ansible

sudo ./grade/grade.sh            # nilai semua soal
sudo ./grade/grade.sh 11 13      # nilai soal tertentu

sudo ./prep/cleanup.sh           # reset state di node
sudo ./prep/cleanup.sh --purge   # + hapus materials server, alias hosts, repo git
```

Opsi lain: `prep-q01.sh --full` (uninstall ansible-core & navigator), `prep-q01.sh --fresh` (pindahkan `/home/greg/ansible` lama ke `.bak-<waktu>`), `--reset` di prep 3, 4, 13, 15, 20 untuk menghapus file jawaban soal itu saja.

Info lab untuk peserta ditulis ke `/home/greg/ex294/` (`README-lab.txt`, `q02-repo.txt`).

## Asumsi lab

Minimal **6 VM RHEL 9**: 1 control node + 5 managed node (dev, test, 2× prod, balancers), sesuai dump. Default IP ada di `prep/env.sh` dan bisa di-override:

```bash
DEV_HOSTS=192.168.122.11 PROD_HOSTS="192.168.122.13 192.168.122.14" sudo -E ./prep/prep-q05.sh
```

- **SSH:** root di control node harus bisa `ssh root@<node>` tanpa password. Kalau lab Anda hanya punya key untuk user lain (mis. `student` di classroom RH294), isi `SSH_USER=student` (butuh sudo NOPASSWD di node).
- **Materials server:** `setup-lab.sh` menjalankan `python3 -m http.server` di port 80 control node (`ex294-materials.service`) dan menambahkan alias `materials` & `content` ke `/etc/hosts` semua mesin. Jadi URL soal `http://materials/...` dan `http://content/Rhce/...` bisa dipakai apa adanya. Port 80 di control node harus kosong.
- **Collections:** urutan sumber: tarball manual di `prep/files/collections/`, lalu Galaxy (butuh internet), lalu ekstrak RPM (`rhel-system-roles`, dll.) lewat `dnf download`. Kalau `rhel-system-roles` tidak tersedia, dipakai `fedora.linux_system_roles` dari Galaxy. Nama FQCN yang dipakai lab ditulis di `README-lab.txt`. Dependencies system roles dikosongkan supaya install dari URL tetap jalan offline.
- **Repo (Soal 2):** URL dideteksi dari repo BaseOS yang sudah ada di node pertama. Bisa juga diisi manual lewat `REPO_PREFIX`, atau pakai ISO RHEL 9 lewat `RHEL_ISO` (di-mount dan disajikan materials server).
- **ansible-navigator:** paketnya ada di repo AAP. Tanpa subscription AAP: `pip3 install --user ansible-navigator`. Tanpa registry `utility.lab.example.com`, jalankan dengan `--ee false` atau pakai `ansible-playbook`.
- **Soal 18:** VG `research` dibuat dari **file loop** (`/var/lib/ex294/research.img`, aktif lagi saat boot lewat `ex294-research-loop.service`): 2 GiB di dev+test (LV 1500M muat), 1 GiB di prod (fallback 800M), tidak ada di balancers (`vg not found`). Disk asli tidak disentuh.
- **Soal 19:** butuh disk kosong `/dev/vdd` di balancers. `prep-q19.sh` hanya membersihkan disk itu kalau tidak sedang dipakai. Tanpa disk, yang diuji cabang `Disk does not exist`.

## Urutan soal

- Soal 5 butuh role dari Soal 4. Soal 6, 7, 8, 10, 18, 19, 21 memakai modul dari collections Soal 3 (`ansible.posix`, `community.general`, system roles).
- Soal 9 butuh repo yang jalan (Soal 2 atau repo bawaan lab).
- Soal 10 butuh httpd di dev (Soal 6).
- Soal 17 butuh `locker.yml` dan `secret.txt` dari Soal 15.
- Soal 20 meng-commit `issue.yml` dan `webcontent.yml` dari Soal 12 dan 10.
