# EX294 Practice Exam — RHCE (RHEL 9)

**Time limit:** 4 hours · **Core:** 17 tasks = 300 points · **Pass:** 210
**Bonus:** Task 8, 19, 20 and 21 (15 points each, not counted toward pass)

Task 8 and Task 19 are the "alternative" tasks from the dump: in the real exam you get **either** Task 7 or Task 8, and **either** Task 18 or Task 19. Tasks 20–21 cover exam objectives that the dump does not test (ansible-navigator.yml, Git, archiving).

## Exam environment (self-lab)

| Role | Host | IP |
|---|---|---|
| Control node | `workstation.lab.example.com` (also `content.example.com`) | `10.10.101.91` |
| dev | `servera.lab.example.com` | `10.10.101.92` |
| test | `serverb.lab.example.com` | `10.10.101.93` |
| prod | `serverc.lab.example.com` | `10.10.101.94` |
| balancers | `serverd.lab.example.com` | `10.10.101.95` |

| Item | Value |
|---|---|
| Exam user | `student` / `redhat` on every machine, passwordless sudo |
| Resources | `http://content.example.com/Rhce/` |
| RHEL 9 DVD | `http://content.example.com/rhel9.0/x86_64/dvd/` |
| Container registry | `utility.lab.example.com` (only exists in the real exam) |

> The real exam (from the dump) uses user `greg`, `/home/greg/ansible`, five managed nodes by IP (`172.25.250.9`–`.13`, prod = two hosts) and root SSH keys. The tasks are the same; only names differ. Your lab values live in `prep/profiles/selflab.env` and `/home/student/ex294/README-lab.txt`.

General rules (same as the real exam):

- `student` on the control node can SSH to `student@<node>` without a password and has passwordless sudo there. Do **not** modify the SSH configuration of root or student.
- All your work (playbooks, configuration files, inventory, roles, collections) must be in **`/home/student/ansible`** on the control node and must be **owned by `student`**.
- All Ansible commands must be run **as `student` from `/home/student/ansible`**. Use `ansible-navigator run -m stdout` or `ansible-playbook`.
- SELinux is **enforcing** on all nodes.
- Everything must keep working after a reboot of the managed nodes.
- Run `prep/prep-qNN.sh` before each task, or `prep/prep-all.sh` once. Grade with `grade/grade.sh`.

---

## Task 1 — Install and configure Ansible (20 pts)

On the control node:

1. Install the required packages (`ansible-core` and `ansible-navigator`).
2. Create the static inventory `/home/student/ansible/inventory`:
   - `servera.lab.example.com` is a member of the `dev` host group
   - `serverb.lab.example.com` is a member of the `test` host group
   - `serverc.lab.example.com` is a member of the `prod` host group
   - `serverd.lab.example.com` is a member of the `balancers` host group
   - the `prod` group is a member of the `webservers` host group
3. Create `/home/student/ansible/ansible.cfg`:
   - the inventory file is `/home/student/ansible/inventory`
   - the roles path is `/home/student/ansible/roles`
   - the collections path is `/home/student/ansible/mycollections`
   - Ansible connects as `student` and uses privilege escalation (`sudo`) to `root` without asking for a password
4. `ansible all -m ping` must succeed for every managed node, and `ansible all -m command -a whoami` must print `root`.

## Task 2 — Configure yum repositories (20 pts)

Create the playbook `/home/student/ansible/yum_repo.yml` that configures two repositories on **all** managed nodes:

| Repository | Name / description | Base URL |
|---|---|---|
| `EX294_BASE` | `EX294 base software` | `http://content.example.com/rhel9.0/x86_64/dvd/BaseOS` |
| `EX294_STREAM` | `EX294 stream software` | `http://content.example.com/rhel9.0/x86_64/dvd/AppStream` |

GPG checking is enabled for both, with the key `http://content.example.com/rhel9.0/x86_64/dvd/RPM-GPG-KEY-redhat-release`.

Both repositories must be enabled.

> Older exam variant: the same result built with ad-hoc commands in an executable script `/home/student/ansible/adhoc.sh`. Either method is accepted by the grader.

## Task 3 — Install Ansible Content Collections (15 pts)

1. Create the directory `/home/student/ansible/mycollections`.
2. Install the following collections into that directory:
   - `http://content.example.com/Rhce/ansible-posix.tar.gz`
   - `http://content.example.com/Rhce/rhel_system_roles.tar.gz` (system roles; its exact name is in `/home/student/ex294/README-lab.txt`)
   - `http://content.example.com/Rhce/community-general.tar.gz`
3. `ansible-galaxy collection list` (run as student in `/home/student/ansible`) must show them from `/home/student/ansible/mycollections`.

## Task 4 — Install roles with a requirements file (15 pts)

1. Create the directory `/home/student/ansible/roles`.
2. Create `/home/student/ansible/roles/requirements.yml` that installs:
   - role `balancer` from `http://content.example.com/Rhce/balancer.tgz`
   - role `phpinfo` from `http://content.example.com/Rhce/phpinfo.tgz`
3. Install both roles into `/home/student/ansible/roles` using that file.

## Task 5 — Use roles from Ansible Galaxy (20 pts)

Create `/home/student/ansible/roles.yml`:

- One play runs on the `webservers` host group and uses the `phpinfo` role. Browsing to `http://serverc.lab.example.com/hello.php` shows `Hello PHP World from serverc.lab.example.com` (the FQDN of that host).
- One play runs on the `balancers` host group and uses the `balancer` role. Browsing to `http://serverd.lab.example.com/` shows `Welcome to serverc.lab.example.com on 10.10.101.94`.

> In the real exam prod has two hosts, so reloading the balancer page alternates between them. With one prod host the page always shows serverc.

## Task 6 — Create and use a role (20 pts)

Create the role `apache` in `/home/student/ansible/roles`:

- The `httpd` package is installed, started and enabled at boot.
- `firewalld` is running and enabled, with a **permanent** rule that allows access to the web server.
- The template `index.html.j2` creates `/var/www/html/index.html` with the content
  `Welcome to HOSTNAME on IPADDRESS`
  where HOSTNAME is the fully qualified domain name of the managed node and IPADDRESS is its IP address.

Create `/home/student/ansible/httpd.yml` that runs the role on the `dev` host group.

## Task 7 — Use the timesync RHEL system role (15 pts)

Create `/home/student/ansible/timesync.yml` that runs on **all** managed nodes and uses the `timesync` role from the system roles collection installed in Task 3:

- NTP server `172.25.254.254` (it does not have to be reachable in the self-lab; only the configuration is graded)
- `iburst` enabled

## Task 8 — BONUS (alternative to Task 7): Use the selinux RHEL system role (15 pts)

Create `/home/student/ansible/selinux.yml` that runs on all managed nodes and uses the `selinux` system role to set SELinux to **enforcing** mode with the **targeted** policy, both at runtime and persistently.

## Task 9 — Install packages (15 pts)

Create `/home/student/ansible/packages.yml`:

- Install `php` and `mariadb` on the hosts in the `dev`, `test` and `prod` host groups.
- Install the `RPM Development Tools` package group on the hosts in the `dev` host group.
- Update **all** packages to the latest version on the hosts in the `dev` host group.

## Task 10 — Create web content (20 pts)

Create `/home/student/ansible/webcontent.yml` that runs on the `dev` host group:

- Create the directory `/webdev`:
  - group owner is `webdev` (the group already exists)
  - permissions: owner `rwx`, group `rwx`, other `r-x`
  - special permission: set group ID
- Create a symbolic link `/var/www/html/webdev` → `/webdev`.
- Create `/webdev/index.html` with the single line `Development`.
- Browsing to `http://servera.lab.example.com/webdev/` shows `Development`.

## Task 11 — Generate a hardware report (20 pts)

Create `/home/student/ansible/hwreport.yml` that creates `/root/hwreport.txt` on **all** managed nodes:

- Download `http://content.example.com/Rhce/hwreport.empty` and save it as `/root/hwreport.txt`.
- Replace each line with the correct `key=value` pair:
  - `HOST` — inventory hostname
  - `MEMORY` — total memory in MB
  - `BIOS` — BIOS version
  - `DISK_SIZE_VDA` — size of disk device `vda`
  - `DISK_SIZE_VDB` — size of disk device `vdb`
- If a hardware item does not exist, its value must be `NONE`.

## Task 12 — Modify file content (15 pts)

Create `/home/student/ansible/issue.yml` that runs on all inventory hosts and replaces the content of `/etc/issue` with one line:

- hosts in `dev`: `Development`
- hosts in `test`: `Test`
- hosts in `prod`: `Production`

## Task 13 — Generate a hosts file with a template (20 pts)

- Download `http://content.example.com/Rhce/hosts.j2` and `http://content.example.com/Rhce/hosts.yml` to `/home/student/ansible`. Do **not** modify `hosts.yml`.
- Complete `hosts.j2` so that it produces, after the two existing `localhost` lines, **one line for every inventory host** in the same format as `/etc/hosts`: `IP-address FQDN short-hostname`.
- Run `hosts.yml`. Afterwards `/etc/myhosts` on the hosts in the `dev` group contains one line for each managed host.

## Task 14 — Configure a cron job (15 pts)

Create `/home/student/ansible/cron.yml` that runs on all managed nodes and configures a cron job for user `natasha` that runs **every 2 minutes** and executes:

```
logger "EX294 in progress"
```

## Task 15 — Create a password vault (15 pts)

- Create the vault `/home/student/ansible/locker.yml` with two variables:
  - `pw_developer` with value `Imadev`
  - `pw_manager` with value `Imamgr`
- The vault password is `whenyouwishuponastar`.
- Store the vault password in `/home/student/ansible/secret.txt`.

## Task 16 — Rekey an existing vault (15 pts)

- Download `http://content.example.com/Rhce/salaries.yml` to `/home/student/ansible`.
- Current vault password: `insecure8sure`. New vault password: `bbs2you9527`.
- The file must remain encrypted with the new password.

## Task 17 — Create user accounts (20 pts)

Download `http://content.example.com/Rhce/user_list.yml` to `/home/student/ansible`. Create `/home/student/ansible/create_users.yml` that uses `user_list.yml` and the vault `locker.yml` from Task 15:

- Users whose `job` is `developer`: created on the hosts in `dev` and `test`, with the UID from the list, supplementary group `devops`, password from `pw_developer` (SHA512 hash), and password maximum age from `password_expire_days`.
- Users whose `job` is `manager`: created on the hosts in `prod`, with the UID from the list, supplementary group `opsmgr`, password from `pw_manager` (SHA512 hash), and password maximum age from `password_expire_days`.
- Use `when` conditions to select the users. Use the vault password file from Task 15 when you run the playbook.

## Task 18 — Create a logical volume (20 pts)

Create `/home/student/ansible/lvm.yml` that runs on **all** managed nodes:

- Create a logical volume `data` of **1500 MiB** in the volume group `research`.
- If the volume group does not have enough space, print the message `Insufficient size of vg` and create the logical volume with **800 MiB** instead.
- If the volume group `research` does not exist, print the message `vg not found`.
- Format the logical volume with `ext4`. Do **not** mount it.

## Task 19 — BONUS (alternative to Task 18): Create a partition (15 pts)

Create `/home/student/ansible/part.yml` that runs on the `balancers` host group:

- Create partition number 1 of **1500 MiB** on `/dev/vdd`, format it as `ext4` and mount it persistently on `/newpart1`.
- If there is not enough space, print `Could not create partition of that size` and create an **800 MiB** partition instead.
- If `/dev/vdd` does not exist, print `Disk does not exist`.

## Task 20 — BONUS: ansible-navigator.yml and Git (15 pts)

1. Create `/home/student/ansible/ansible-navigator.yml` so that `ansible-navigator`:
   - uses `stdout` mode by default
   - does not create playbook artifacts
   - uses the execution environment image `utility.lab.example.com/ee-supported-rhel9:latest` with pull policy `missing`
2. Clone the Git repository `/srv/git/ex294-playbooks.git` to `/home/student/ex294-playbooks`, add your `issue.yml` and `webcontent.yml` to it, commit with the message `Add RHCE playbooks`, and push to the `main` branch.

## Task 21 — BONUS: Archiving (15 pts)

Create `/home/student/ansible/archive.yml`:

- On the hosts in `prod`: create the gzip-compressed archive `/root/sshconf.tar.gz` that contains the directory `/etc/ssh`.
- On the hosts in `dev`: extract `http://content.example.com/Rhce/ex294-docs.tar.gz` into `/srv/docs` (so `/srv/docs/docs/README.txt` exists).
