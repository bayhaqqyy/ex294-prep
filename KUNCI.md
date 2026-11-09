# KUNCI JAWABAN — EX294 Practice (RHEL 9)

> Semua perintah dijalankan di control node sebagai `greg` dari `/home/greg/ansible` (kecuali disebut lain).
> IP/URL di bawah memakai nilai default. Nilai lab Anda ada di `/home/greg/ex294/README-lab.txt` dan `q02-repo.txt`.
> Kalau lupa nama parameter modul: `ansible-doc <modul>` atau `ansible-navigator doc <modul> -m stdout`. Keduanya boleh dipakai di ujian.

## Koreksi dari dump `rhce_v1.5.pdf`

Dump-nya berguna untuk pola soal, tapi beberapa jawabannya **salah** dan bakal bikin poin hilang:

| Soal | Di dump | Yang benar |
|---|---|---|
| 1 | `ansible_password=root` di inventory | Tidak perlu. SSH key sudah terpasang; password di inventory malah butuh `sshpass`. Cukup `remote_user=root` di `ansible.cfg` |
| 2B | `hosts: app` | Grup `app` tidak ada → `hosts: all` |
| 4 | `-r /home/admin/ansible/...` | Typo, harusnya `/home/greg/ansible/roles/requirements.yml` |
| 8 | Memakai role `...timesync` untuk SELinux | Role yang benar `redhat.rhel_system_roles.selinux` |
| 7/8 | `redhat-rhel_system_roles.timesync` | Nama FQCN memakai titik: `redhat.rhel_system_roles.timesync` |
| 9 | `Hosts:` / `Tasks:` huruf besar | Keyword YAML Ansible huruf kecil semua (`hosts`, `tasks`), kalau tidak playbook error |
| 10 | Symlink ke `/var/www/html/devweb` | Soal minta `/var/www/html/webdev` |
| 10 | Hanya `setype` di module `file` | Konteks hilang kalau ada `restorecon`/relabel. Daftarkan juga dengan `community.general.sefcontext` |
| 11 | `regexp: "{{ item.hw_name }}"` | Pakai `^HOST=` dsb. supaya tidak salah cocok baris lain |
| 13 | `{{ ansible_default_ipv4.address }}` di dalam loop | Itu fakta host **yang sedang dijalankan**, jadi semua baris sama. Harus `hostvars[host]['ansible_facts'][...]` |
| 15 | `chmod 600 sercret.txt` | Typo, `secret.txt` |
| 17 | `–vault-password-file`, tanda kutip miring `“ ”` | Dua tanda minus `--`, kutip lurus `" "` |
| 18 | Nama VG campur `research` / `vg_research`, `when` di dalam block salah indentasi, yang dijalankan `roles.yml` | Konsisten `research`, pakai `block/rescue`, jalankan `lvm.yml` |

---

## Persiapan awal ujian

```bash
ssh greg@workstation                         # di lab: ssh greg@172.25.250.254
podman login utility.lab.example.com         # user/password dari bagian Important information
```

`ansible-navigator` memakai execution environment (EE) dari registry itu. Di lab latihan **tanpa** registry, tambahkan `--ee false`:
`ansible-navigator run -m stdout --ee false <playbook>`. Atau pakai `ansible-playbook <playbook>`, hasilnya sama.

---

## Soal 1 — Install & konfigurasi Ansible

```bash
sudo dnf install -y ansible-core ansible-navigator
# lab tanpa repo AAP: pip3 install --user ansible-navigator
mkdir -p /home/greg/ansible && cd /home/greg/ansible
```

`inventory`:

```ini
[dev]
172.25.250.9

[test]
172.25.250.10

[prod]
172.25.250.11
172.25.250.12

[balancers]
172.25.250.13

[webservers:children]
prod
```

`ansible.cfg`:

```ini
[defaults]
inventory = /home/greg/ansible/inventory
roles_path = /home/greg/ansible/roles
collections_path = /home/greg/ansible/mycollections
remote_user = root
host_key_checking = False
```

> Variasi soal yang meminta user `greg` + privilege escalation: ganti `remote_user = greg` lalu tambahkan
> `[privilege_escalation]` dengan `become = True`, `become_method = sudo`, `become_user = root`, `become_ask_pass = False`.

Verifikasi:

```bash
ansible --version                 # "config file = /home/greg/ansible/ansible.cfg"
ansible-inventory --graph         # webservers -> prod -> .11 .12
ansible all -m ping
```

## Soal 2 — Repository

`yum_repo.yml` (ganti prefix dengan isi `~/ex294/q02-repo.txt`):

```yaml
---
- name: Configure EX294 repositories
  hosts: all
  tasks:
    - name: EX294_BASE
      ansible.builtin.yum_repository:
        name: EX294_BASE
        description: EX294 base software
        baseurl: http://content.example.com/rhel9.3/x86_64/dvd/BaseOS
        gpgcheck: true
        gpgkey: http://content.example.com/rhel9.3/x86_64/dvd/RPM-GPG-KEY-redhat-release
        enabled: true

    - name: EX294_STREAM
      ansible.builtin.yum_repository:
        name: EX294_STREAM
        description: EX294 stream software
        baseurl: http://content.example.com/rhel9.3/x86_64/dvd/AppStream
        gpgcheck: true
        gpgkey: http://content.example.com/rhel9.3/x86_64/dvd/RPM-GPG-KEY-redhat-release
        enabled: true
```

```bash
ansible-navigator run -m stdout yum_repo.yml
ansible all -m command -a 'dnf repolist'
```

Variasi lama, `adhoc.sh` (jangan lupa `chmod +x adhoc.sh` lalu jalankan `./adhoc.sh`):

```bash
#!/bin/bash
P=http://content.example.com/rhel9.3/x86_64/dvd
ansible all -m ansible.builtin.yum_repository -a "name=EX294_BASE description='EX294 base software' baseurl=$P/BaseOS gpgcheck=yes gpgkey=$P/RPM-GPG-KEY-redhat-release enabled=yes"
ansible all -m ansible.builtin.yum_repository -a "name=EX294_STREAM description='EX294 stream software' baseurl=$P/AppStream gpgcheck=yes gpgkey=$P/RPM-GPG-KEY-redhat-release enabled=yes"
```

## Soal 3 — Collections

```bash
mkdir -p /home/greg/ansible/mycollections
ansible-galaxy collection install http://content/Rhce/ansible-posix.tar.gz     -p /home/greg/ansible/mycollections
ansible-galaxy collection install http://content/Rhce/rhel_system_roles.tar.gz -p /home/greg/ansible/mycollections
ansible-galaxy collection install http://content/Rhce/community-general.tar.gz -p /home/greg/ansible/mycollections
ansible-galaxy collection list
```

Warning "path is not part of the configured Ansible collections paths" tidak muncul kalau `collections_path` di `ansible.cfg` sudah benar.

## Soal 4 — Role dari URL

`roles/requirements.yml`:

```yaml
---
- src: http://content/Rhce/balancer.tgz
  name: balancer
- src: http://content/Rhce/phpinfo.tgz
  name: phpinfo
```

```bash
ansible-galaxy role install -r /home/greg/ansible/roles/requirements.yml -p /home/greg/ansible/roles
ansible-galaxy role list
```

## Soal 5 — Role balancer & phpinfo

`roles.yml` (urutan penting: webservers dulu, baru balancer):

```yaml
---
- name: PHP info on webservers
  hosts: webservers
  roles:
    - phpinfo

- name: Load balancer
  hosts: balancers
  roles:
    - balancer
```

```bash
ansible-navigator run -m stdout roles.yml
curl http://172.25.250.11/hello.php | head -1
curl http://172.25.250.13/ ; curl http://172.25.250.13/     # dua backend bergantian
```

## Soal 6 — Role apache

```bash
cd /home/greg/ansible/roles && ansible-galaxy role init apache && cd ..
```

`roles/apache/tasks/main.yml`:

```yaml
---
- name: Install httpd
  ansible.builtin.dnf:
    name: httpd
    state: present

- name: Start and enable httpd
  ansible.builtin.service:
    name: httpd
    state: started
    enabled: true

- name: Start and enable firewalld
  ansible.builtin.service:
    name: firewalld
    state: started
    enabled: true

- name: Allow http
  ansible.posix.firewalld:
    service: http
    permanent: true
    immediate: true
    state: enabled

- name: Deploy index.html
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html
    mode: "0644"
```

`roles/apache/templates/index.html.j2`:

```jinja
Welcome to {{ ansible_facts['fqdn'] }} on {{ ansible_facts['default_ipv4']['address'] }}
```

`httpd.yml`:

```yaml
---
- name: Apache on dev
  hosts: dev
  roles:
    - apache
```

```bash
ansible-navigator run -m stdout httpd.yml
curl http://172.25.250.9/
```

## Soal 7 — timesync system role

```bash
ansible-galaxy collection list | grep -i system_roles     # pastikan nama FQCN-nya
ansible-doc -l redhat.rhel_system_roles 2>/dev/null | head    # opsional
```

`timesync.yml`:

```yaml
---
- name: Configure time synchronization
  hosts: all
  vars:
    timesync_ntp_servers:
      - hostname: 172.25.254.254
        iburst: true
  roles:
    - redhat.rhel_system_roles.timesync
```

Dokumentasi variabel ada di `mycollections/ansible_collections/redhat/rhel_system_roles/roles/timesync/README.md`.

```bash
ansible-navigator run -m stdout timesync.yml
ansible all -m command -a 'chronyc sources'
```

## Soal 8 (bonus) — selinux system role

```yaml
---
- name: SELinux enforcing
  hosts: all
  vars:
    selinux_policy: targeted
    selinux_state: enforcing
  roles:
    - redhat.rhel_system_roles.selinux
```

```bash
ansible-navigator run -m stdout selinux.yml
ansible all -m command -a 'getenforce'
ansible all -m command -a 'grep ^SELINUX= /etc/selinux/config'
```

Kalau node sebelumnya `disabled`, role akan minta reboot (`selinux_reboot_required`). Di lab ini tidak terjadi karena prep hanya mengubah config ke `permissive`.

## Soal 9 — Paket

`packages.yml`:

```yaml
---
- name: php and mariadb
  hosts: dev,test,prod
  tasks:
    - name: Install php and mariadb
      ansible.builtin.dnf:
        name:
          - php
          - mariadb
        state: present

- name: Development tools on dev
  hosts: dev
  tasks:
    - name: Install RPM Development Tools group
      ansible.builtin.dnf:
        name: "@RPM Development Tools"
        state: present

    - name: Update all packages
      ansible.builtin.dnf:
        name: "*"
        state: latest
```

## Soal 10 — /webdev

`webcontent.yml`:

```yaml
---
- name: Web content on dev
  hosts: dev
  tasks:
    - name: Create /webdev
      ansible.builtin.file:
        path: /webdev
        state: directory
        group: webdev
        mode: "2775"

    - name: SELinux context for /webdev (persistent)
      community.general.sefcontext:
        target: "/webdev(/.*)?"
        setype: httpd_sys_content_t
        state: present

    - name: Create index.html
      ansible.builtin.copy:
        content: "Development\n"
        dest: /webdev/index.html
        mode: "0644"

    - name: Apply SELinux context
      ansible.builtin.command: restorecon -Rv /webdev
      register: webdev_restorecon
      changed_when: webdev_restorecon.stdout | length > 0

    - name: Symlink /var/www/html/webdev
      ansible.builtin.file:
        src: /webdev
        dest: /var/www/html/webdev
        state: link

    - name: httpd running
      ansible.builtin.service:
        name: httpd
        state: started
        enabled: true

    - name: Allow http
      ansible.posix.firewalld:
        service: http
        permanent: true
        immediate: true
        state: enabled
```

```bash
curl http://172.25.250.9/webdev/          # Development
```

Mode `2775` = setgid (2) + rwx/rwx/r-x. Cek: `ansible dev -m command -a 'ls -ldZ /webdev /webdev/index.html'`.

## Soal 11 — Hardware report

`hwreport.yml`:

```yaml
---
- name: Hardware report
  hosts: all
  tasks:
    - name: Download template
      ansible.builtin.get_url:
        url: http://materials/hwreport.empty
        dest: /root/hwreport.txt
        force: true

    - name: Fill in values
      ansible.builtin.lineinfile:
        path: /root/hwreport.txt
        regexp: "^{{ item.key }}="
        line: "{{ item.key }}={{ item.value }}"
      loop:
        - key: HOST
          value: "{{ inventory_hostname }}"
        - key: MEMORY
          value: "{{ ansible_facts['memtotal_mb'] }}"
        - key: BIOS
          value: "{{ ansible_facts['bios_version'] if ansible_facts['bios_version'] | default('NA') != 'NA' else 'NONE' }}"
        - key: DISK_SIZE_VDA
          value: "{{ ansible_facts['devices']['vda']['size'] | default('NONE') }}"
        - key: DISK_SIZE_VDB
          value: "{{ ansible_facts['devices']['vdb']['size'] | default('NONE') }}"
```

`default('NONE')` tetap aman walaupun `vdb` tidak ada, karena Ansible mengizinkan rantai atribut pada variabel undefined sebelum filter `default`.
Untuk BIOS, Ansible mengisi `NA` (bukan undefined) kalau datanya tidak terbaca. Karena itu `default('NONE', true)` versi dump tidak pernah menghasilkan `NONE`; ekspresi di atas mengubah `NA` menjadi `NONE`.

```bash
ansible all -m command -a 'cat /root/hwreport.txt'
```

## Soal 12 — /etc/issue

```yaml
---
- name: /etc/issue per group
  hosts: all
  tasks:
    - name: dev
      ansible.builtin.copy:
        content: "Development\n"
        dest: /etc/issue
      when: inventory_hostname in groups['dev']

    - name: test
      ansible.builtin.copy:
        content: "Test\n"
        dest: /etc/issue
      when: inventory_hostname in groups['test']

    - name: prod
      ansible.builtin.copy:
        content: "Production\n"
        dest: /etc/issue
      when: inventory_hostname in groups['prod']
```

## Soal 13 — hosts.j2

```bash
cd /home/greg/ansible
wget http://materials/hosts.j2 http://materials/hosts.yml     # atau curl -O
```

Tambahkan di bawah dua baris `localhost` pada `hosts.j2`:

```jinja
{% for host in groups['all'] %}
{{ hostvars[host]['ansible_facts']['default_ipv4']['address'] }} {{ hostvars[host]['ansible_facts']['fqdn'] }} {{ hostvars[host]['ansible_facts']['hostname'] }}
{% endfor %}
```

`hosts.yml` dari soal berjalan di `hosts: all` dan memakai `when` untuk grup dev. Itu yang membuat fakta **semua** host terkumpul, sehingga `hostvars[host]` terisi.

```bash
ansible-navigator run -m stdout hosts.yml
ansible dev -m command -a 'cat /etc/myhosts'
```

## Soal 14 — Cron

```yaml
---
- name: Cron job for natasha
  hosts: all
  tasks:
    - name: logger every 2 minutes
      ansible.builtin.cron:
        name: ex294 logger
        user: natasha
        minute: "*/2"
        job: 'logger "EX294 in progress"'
```

```bash
ansible all -m command -a 'crontab -l -u natasha'
```

## Soal 15 — Vault

```bash
echo 'whenyouwishuponastar' > secret.txt
chmod 600 secret.txt
ansible-vault create --vault-password-file=secret.txt locker.yml
```

Isi di editor:

```yaml
---
pw_developer: Imadev
pw_manager: Imamgr
```

```bash
ansible-vault view --vault-password-file=secret.txt locker.yml
```

## Soal 16 — Rekey

```bash
wget http://materials/salaries.yml
ansible-vault rekey --ask-vault-pass salaries.yml
#   Vault password:          insecure8sure
#   New Vault password:      bbs2you9527
#   Confirm New Vault password: bbs2you9527
ansible-vault view salaries.yml        # password baru
```

## Soal 17 — User

```bash
wget http://content/Rhce/user_list.yml
```

`create_users.yml`:

```yaml
---
- name: Create users
  hosts: all
  vars_files:
    - user_list.yml
    - locker.yml
  tasks:
    - name: Groups
      ansible.builtin.group:
        name: "{{ item }}"
        state: present
      loop:
        - devops
        - opsmgr

    - name: Developers on dev and test
      ansible.builtin.user:
        name: "{{ item.name }}"
        uid: "{{ item.uid }}"
        groups: devops
        append: true
        password: "{{ pw_developer | password_hash('sha512') }}"
        password_expire_max: "{{ item.password_expire_days }}"
      loop: "{{ users }}"
      when:
        - item.job == 'developer'
        - inventory_hostname in groups['dev'] or inventory_hostname in groups['test']

    - name: Managers on prod
      ansible.builtin.user:
        name: "{{ item.name }}"
        uid: "{{ item.uid }}"
        groups: opsmgr
        append: true
        password: "{{ pw_manager | password_hash('sha512') }}"
        password_expire_max: "{{ item.password_expire_days }}"
      loop: "{{ users }}"
      when:
        - item.job == 'manager'
        - inventory_hostname in groups['prod']
```

```bash
ansible-navigator run -m stdout create_users.yml --vault-password-file=secret.txt
ansible dev,test -m command -a 'id bob'
ansible prod -m command -a 'chage -l sally'
```

> Kalau memakai EE dan file vault password tidak terbaca di container, jalankan dengan `ansible-playbook create_users.yml --vault-password-file=secret.txt`, atau tambahkan `vault_password_file = /home/greg/ansible/secret.txt` di `ansible.cfg`.

## Soal 18 — LVM

`lvm.yml`:

```yaml
---
- name: Logical volume data
  hosts: all
  tasks:
    - name: VG research missing
      ansible.builtin.debug:
        msg: vg not found
      when: "'research' not in ansible_facts['lvm']['vgs'] | default({})"

    - name: Create LV when VG research exists
      when: "'research' in ansible_facts['lvm']['vgs'] | default({})"
      block:
        - name: LV 1500M
          community.general.lvol:
            vg: research
            lv: data
            size: 1500m
      rescue:
        - name: Not enough space
          ansible.builtin.debug:
            msg: Insufficient size of vg

        - name: LV 800M
          community.general.lvol:
            vg: research
            lv: data
            size: 800m
      always:
        - name: ext4
          community.general.filesystem:
            fstype: ext4
            dev: /dev/research/data
```

`when` di level block ikut berlaku untuk `rescue` dan `always`, jadi host tanpa VG tidak menyentuh LVM sama sekali.

```bash
ansible-navigator run -m stdout lvm.yml
ansible all -m command -a 'lvs'
ansible all -m command -a 'blkid /dev/research/data'
```

## Soal 19 (bonus) — Partisi

`part.yml`:

```yaml
---
- name: Partition on balancers
  hosts: balancers
  tasks:
    - name: Disk missing
      ansible.builtin.debug:
        msg: Disk does not exist
      when: ansible_facts['devices']['vdd'] is not defined

    - name: Partition vdd
      when: ansible_facts['devices']['vdd'] is defined
      block:
        - name: Partition 1500MiB
          community.general.parted:
            device: /dev/vdd
            number: 1
            state: present
            part_end: 1500MiB
      rescue:
        - name: Not enough space
          ansible.builtin.debug:
            msg: Could not create partition of that size

        - name: Partition 800MiB
          community.general.parted:
            device: /dev/vdd
            number: 1
            state: present
            part_end: 800MiB
      always:
        - name: ext4
          community.general.filesystem:
            fstype: ext4
            dev: /dev/vdd1

        - name: Mount /newpart1
          ansible.posix.mount:
            path: /newpart1
            src: /dev/vdd1
            fstype: ext4
            state: mounted
```

## Soal 20 (bonus) — ansible-navigator.yml & Git

`/home/greg/ansible/ansible-navigator.yml`:

```yaml
---
ansible-navigator:
  mode: stdout
  playbook-artifact:
    enable: false
  execution-environment:
    image: utility.lab.example.com/ee-supported-rhel9:latest
    pull:
      policy: missing
```

```bash
git clone /srv/git/ex294-playbooks.git /home/greg/ex294-playbooks
cd /home/greg/ex294-playbooks
git config user.name greg; git config user.email greg@lab.example.com
cp /home/greg/ansible/issue.yml /home/greg/ansible/webcontent.yml .
git add issue.yml webcontent.yml
git commit -m "Add RHCE playbooks"
git push origin main
```

> Di lab tanpa registry, setelah file ini dibuat semua `ansible-navigator run` butuh `--ee false`, atau set `execution-environment.enabled: false` sementara.

## Soal 21 (bonus) — Archive

`archive.yml`:

```yaml
---
- name: Archive SSH config on prod
  hosts: prod
  tasks:
    - name: /root/sshconf.tar.gz
      community.general.archive:
        path: /etc/ssh
        dest: /root/sshconf.tar.gz
        format: gz

- name: Extract docs on dev
  hosts: dev
  tasks:
    - name: /srv/docs
      ansible.builtin.file:
        path: /srv/docs
        state: directory
        mode: "0755"

    - name: Extract bundle
      ansible.builtin.unarchive:
        src: http://content/Rhce/ex294-docs.tar.gz
        dest: /srv/docs
        remote_src: true
```
