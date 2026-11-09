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

## Topologi lab (default: self-lab)

Default repo ini mengikuti dokumen *Preparation Self-Lab RHCE9 EX294* (VM pribadi):

| Role | Hostname | IP | Grup |
|---|---|---|---|
| Control node + `content.example.com` | `workstation.lab.example.com` | 10.10.101.91 | – |
| Managed node | `servera.lab.example.com` | 10.10.101.92 | dev |
| Managed node | `serverb.lab.example.com` | 10.10.101.93 | test |
| Managed node | `serverc.lab.example.com` | 10.10.101.94 | prod (→ webservers) |
| Managed node | `serverd.lab.example.com` | 10.10.101.95 | balancers |

Nilainya ada di [`prep/profiles/selflab.env`](prep/profiles/selflab.env). Topologi dump (user `greg`, 5 node `172.25.250.9`–`.13`, key root) tersedia sebagai profil `exam`: `sudo LAB_PROFILE=exam ./prep/setup-lab.sh`. Nilai mana pun bisa di-override lewat environment.

## Baseline yang diasumsikan sudah ada (bagian 1–13 dokumen)

- 5 VM RHEL 9, IP statis, hostname, dan `/etc/hosts` konsisten di semua mesin (termasuk `content.example.com` → workstation).
- User `student` di semua mesin dengan sudo NOPASSWD, SSH key `student@workstation` → `student@servera..serverd` tanpa password.
- ISO RHEL 9 ter-attach ke workstation (`/dev/sr0`).

`setup-lab.sh` mengecek semua itu dan **melengkapi yang kurang** tanpa mengerjakan jawaban soal:

- user `student`, sudo NOPASSWD, dan SSH key ke node (hanya bila belum ada);
- alias `content.example.com` di `/etc/hosts` (hanya bila belum resolve ke workstation);
- httpd aktif + firewall http, `/var/www/html/Rhce` (+ symlink `rhce`);
- DVD `/dev/sr0` di-mount ke `/var/www/html/rhel9.0/x86_64/dvd` dan dibuat persisten di `/etc/fstab` (dokumen hanya me-mount sementara);
- resource soal di `http://content.example.com/Rhce/`: role `balancer`/`phpinfo`, tarball collections, `hwreport.empty`, `hosts.j2`, `hosts.yml`, `salaries.yml` (vault), `user_list.yml`, `ex294-docs.tar.gz`.

Sesuai prinsip dokumen, repo `.repo` di managed node, user, cron, LV, dan partisi **tidak** dibuat oleh setup — itu jawaban soal.

Perbedaan dengan dokumen yang perlu diperhatikan:

| Dokumen self-lab | Repo ini | Alasan |
|---|---|---|
| `collections_path = .../collections` | `.../mycollections` | Sesuai soal di dump (Soal 1 & 3) |
| Grup `balancer` | `balancers` | Sesuai dump; grader menerima keduanya |
| Inventory & `ansible.cfg` dibuat di baseline | Dibuat di Soal 1 | Itu soal pertama ujian |
| `hwreport.txt` (ada `CPU=`), `myhosts.j2`, `solaris.yml` (password `cisco`) | `hwreport.empty`, `hosts.j2`/`hosts.yml`, `salaries.yml` | Mengikuti soal di dump. File dokumen Anda di `/var/www/html/Rhce` tidak disentuh |

## Cara pakai

Semua script dijalankan **di workstation dengan sudo** (otomatis naik ke root). Jawaban dikerjakan sebagai `student` di `/home/student/ansible`.

```bash
git clone https://github.com/bayhaqqyy/ex294-prep.git ~/ex294-prep
cd ~/ex294-prep
vi prep/profiles/selflab.env     # cek IP/hostname bila lab berubah

sudo ./prep/setup-lab.sh         # sekali, lalu snapshot semua VM (EX294-BASELINE)
sudo ./prep/prep-all.sh          # siapkan & reset semua soal
sudo ./prep/prep-all.sh 9 18     # atau beberapa soal saja

cd ~/ansible                     # kerjakan SOAL.md

sudo ~/ex294-prep/grade/grade.sh          # nilai semua soal
sudo ~/ex294-prep/grade/grade.sh 11 13    # nilai soal tertentu

sudo ./prep/cleanup.sh           # reset state di node
sudo ./prep/cleanup.sh --purge   # + hapus resource buatan prep, alias hosts tambahan, repo git
```

Opsi lain: `prep-q01.sh --full` (uninstall ansible-core & navigator), `prep-q01.sh --fresh` (pindahkan `~/ansible` lama ke `.bak-<waktu>`), `--reset` di prep 3, 4, 13, 15, 20 untuk menghapus file jawaban soal itu saja. Info lab ditulis ke `/home/student/ex294/`.

## Catatan per soal di self-lab

- **Soal 2 & 9:** managed node tidak punya repo sampai Soal 2 dikerjakan, jadi Soal 9 (dan install paket lain) baru jalan setelahnya.
- **Soal 5:** prod hanya `serverc`, jadi halaman balancer selalu menampilkan serverc (di ujian asli bergantian antara dua host).
- **Soal 7:** `172.25.254.254` tidak ada di self-lab; yang dinilai hanya konfigurasi chrony.
- **Soal 18:** `prep-q18.sh` membuat VG `research` dari **file loop** sesuai tabel dokumen: servera & serverc 2 GiB (LV 1500M), serverb 1 GiB (fallback 800M), serverd tanpa VG (`vg not found`). Kalau Anda sudah membuat VG `research` di disk asli (mis. `/dev/vdb`, bagian 21 dokumen), VG itu dipertahankan dan hanya LV `data` yang direset. Grader menentukan ukuran LV yang benar dari ukuran VG masing-masing node.
- **Soal 19:** soal memakai `/dev/vdd` di serverd. Dokumen tidak membuat vdd, jadi yang teruji cabang `Disk does not exist`. Untuk cabang lain, attach disk sebagai vdd (>1.6 GiB untuk 1500MiB, ~1 GiB untuk 800MiB) lalu jalankan `prep-q19.sh`.
- **ansible-navigator:** tanpa registry `utility.lab.example.com`, jalankan dengan `--ee false` atau pakai `ansible-playbook`.
- **Collections:** sumbernya tarball manual di `prep/files/collections/`, lalu Galaxy (butuh internet), lalu ekstrak RPM `rhel-system-roles` lewat `dnf download`. Kalau `rhel-system-roles` tidak tersedia, dipakai `fedora.linux_system_roles`; nama yang dipakai tercatat di `README-lab.txt`.

## Urutan soal

- Soal 5 butuh role dari Soal 4. Soal 6, 7, 8, 10, 18, 19, 21 memakai modul dari collections Soal 3 (`ansible.posix`, `community.general`, system roles).
- Soal 9 butuh repo yang jalan (Soal 2 atau repo bawaan lab).
- Soal 10 butuh httpd di dev (Soal 6).
- Soal 17 butuh `locker.yml` dan `secret.txt` dari Soal 15.
- Soal 20 meng-commit `issue.yml` dan `webcontent.yml` dari Soal 12 dan 10.
